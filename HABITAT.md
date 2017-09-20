# Running Redmine in Habitat

Habitat is an ideal deployment method for large Ruby-on-Rails applications
like Redmine.  Habitat centers application configuration, management, and
behavior around the application itself, not the infrastructure that the app
runs on. This allows Habitat to be deployed and run on various infrastructure
environments, such as bare metal, VM, containers, and PaaS.

Specifically, we want to run Redmine in Habitat either natively, in a docker
container, or as a Cloud Foundry app.  Below you will find instructions on how
to accomplish this.

## Modifications to the Redmine Application

Very little was needed to be modified in the Redmine code base.  There were
some changes on how configuration was passed in, and some gem selection
changes, specifically eliminating optional configurations, as this is an
opinionated install that uses Ruby 2.4.1 and PostgreSQL.  Specifically:

* We do not use `config/database.yml`, as the Habitat `core/scaffolding-ruby`
  uses the `DATABASE_URL` environment variable.  A further reason this is done
  is because the scaffolding ignores files that are git-ignored, as is the
  case for `config/database.yml`

* Similarly, we don't use `config/secrets.yml`, which is also git-ignored, but
  instead updated `config/application.rb` to set the secret from the environment
  variable `SECRET_KEY_BASE`.

* As `config/database.yml` is not present, we cannot use it to determine the
  database gem needed in the `Gemfile`, and instead hardcode to `pg`.

* Also in the `Gemfile`, we hardcoded `ruby` to `2.4.1`, and removed any conditional
  versioning that depended on the ruby version.

* The `tzinfo-data` gem was included for all platforms, as required by the
  Habitat `core/scaffolding-ruby` package.

* Because this is a Rails 4.2 app, had to add the following gems that aren't
  needed if using Rails 5:
  * `rails_12factor` -- while Rails 5 is fully 12factor out of the box, Rails
    4.2 is slightly deficient, and thus needs the rails_12factor gem to run in
    habitat.

  * `activerecord_nulldb_adapter` -- in order for the `rake assets:precompile`
    to run during the build process, it needs to initialize the rails app,
    which needs a db connection, even though it doesn't use one.  This allows
    that to work.

## Install Habitat (and maybe Docker)

In order to use Habitat, you'll need to install the `hab` binary for your
system.  We are using Mac OSX, but it is also available for Linux and Windows.
Follow the [instructions for downloading and installing](https://www.habitat.sh/tutorials/download/).

If you are using Mac or Windows, you'll also need to install Docker; the
installation page also has instructions for that as well.

Once installed, follow the instructions on the next pages of the above link to
create a Habitat account, a personal or orginizational origin, and to
configure your workstation.

## Habitat Plan and Default Configuration

In order to package the Redmine application up with Habitat, we need a Habitat
`plan.sh` file and a `default.toml` configuration file.  We have already
created these files for you, but here are the steps we used to create it so
you can understand the process and tweak it if needed.<sup
id="a1">[1](#f1)</sup>

While these files can be placed in the root of the application repository, we
elected to place them in the `habitat` subdirectory as it is cleaner and better
contained.

#### The `habitat/plan.sh` File

The `plan.sh` file was generated from scratch using `hab plan init -s ruby`,
then modified to the following:

```
pkg_name=redmine
pkg_origin=starkandwayne
pkg_scaffolding="core/scaffolding-ruby"

pkg_version="3.4.2"
pkg_binds_optional=( [database]="port" )

pkg_deps=(core/imagemagick)

pkg_exports=(
  [http_port]=app.port
)
pkg_exposes=(http_port)

# This is necessary due to the installation needing db credentials even though its not used
do_install() {
  export DATABASE_URL="nulldb://nobody@nowhere/fake_db_to_appease_rails_env"
  do_default_install
}
```

While most of this is boilerplate Habitat plan contents, the uncommon items
are:
* The `pkg_binds_optional` -- by making this optional, the Habitat supervisor
  will start up without having another habitat service providing these to our
  app.  This allows external sources for the database.

* The `pkg_exports` and `pkg_exposes`, which is required for making this work on
  Cloud Foundry.  It is very important that the app.port that gets configured
  is LESS THAN the value 9631, which we'll talk about later in the Cloud Foundry
  section below.

* The redefining of `do_install`, which works around the previously mentioned
  `rake assets:precompile` issue during installation that requires the
  database details without actually needing to connect to a database.  In a
  Rails 5 app, the nulldb adaptor wasn't needed, and could simply use
  `postgresql://...`  This may not be needed at all in later
  `core/scaffolding-ruby` releases.<sup
id="a1">[2](#f2)</sup>


#### The `habitat/default.toml` File

The default.toml file contains the base configuration for the packaged Redmine
habitat file that we're going to generate.  It contains both base settings
that are not likely to need changing, as well as default (or empty) values
that should be overwritten by using `hab config apply ...` <sup
id="a1">[3](#f3)</sup> once runtting
or by editing default.toml directly and rebuilding the package for personal
use (be sure not to commit the file if it contains passwords or secrets)
Alternatively, if using Cloud Foundry, these secrets are taken care of in a
later section so don't need to be set here.

The basic contents for the Redmine application's default.toml is:
```
secret_key_base = ""
rails_env = "production"

[app]
port = 8000

[db]
user = "admin"
password = "admin"
name = "redmine_production"
host = "192.168.65.1"
```

The secret_key_base being empty will cause the app to fail to start when first
pushed up.  If you wish to set this in default.toml, but can't or don't want
to get the rails app working on your development machine in order to run `rake
secret` you can simply run the following to get a secure secret key base to
paste into the file:

```
ruby -rsecurerandom -e 'puts SecureRandom.hex(64)'
```

Similarly, the default database configuration is provided as a sample of how
to connect to a database exiting on the host machine when using docker-compose
(more on that later) to run your Habitat package.  Alternatively, you may end
up using a hosted DB solution (such as Amazon RDS) or a database running
under the same Habitat supervisor (as will be our first example below)


# Built Redmine and Export it to Docker

To build the Habitat package, enter into the Habitat studio from the base of
the Redmine repository:

`hab studio enter`

- - -

<b id="f1">[1]</b> These steps were performed by following the excellent "[Habitat, Rails, and
  Postgres in 3 Different
  Ways](https://www.habitat.sh/blog/2017/08/habitat-rails-postgres-3-different-ways/)"
  blog post by Nell Shamrell-Harrinton.  Please read her post to understand
  the process in greater detail. [↩](#s1)

<b id="f2">[2]</b> [[scaffolding-ruby] provide a default database config for asset compilation #757](https://github.com/habitat-sh/core-plans/pull/757) [↩](#s2)

<b id="f3">[3]</b> Habitat tutorial on how to [dynamically update your app](https://www.habitat.sh/tutorials/sample-app/mac/update-app/) [↩](#s3)
