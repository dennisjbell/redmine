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

## Install Habitat (and maybe Docker)

In order to use Habitat, you'll need to install the `hab` binary for your
system.  We are using Mac OSX, but it is also available for Linux and Windows.
Follow the [instructions for downloading and installing](https://www.habitat.sh/tutorials/download/).

If you are using Mac or Windows, you'll also need to install Docker; the
installation page also has instructions for that as well.

## Habitat Plan and Default Configuration

In order to package the Redmine application up with Habitat, we need a Habitat
`plan.sh` file and a `default.toml` configuration file.  We have already
created these files for you, but here are the steps we used to create it so
you can understand the process and tweak it if needed.[^1]

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
  export DATABASE_URL="postgresql://nobody@nowhere/fake_db_to_appease_rails_env"
  do_default_install
}
```

While most of this is boilerplate Habitat plan contents, the uncommon items
are:
* The redefining of `do_install`, which works around an issue during
  installation that requires the database details without actually needing to
  connect to a database.  This may not be needed in later
  `core/scaffolding-ruby` releases.[^2]

* The `pkg_exports` and `pkg_exposes`, which is required for making this work on
  Cloud Foundry.  It is very important that the app.port that gets configured
  is LESS THAN the value 9631, which we'll talk about later in the Cloud Foundry
  section below.

* The `pkg_binds_optional` -- by making this optional, the Habitat supervisor
  will start up without having another habitat service providing these to our
  app.  This allows external sources for the database.


- - -

[^1]: These steps were performed by following the excellent "[Habitat, Rails, and
  Postgres in 3 Different
  Ways](https://www.habitat.sh/blog/2017/08/habitat-rails-postgres-3-different-ways/)"
  blog post by Nell Shamrell-Harrinton.  Please read her post to understand
  the process in greater detail.

[^2]: [[scaffolding-ruby] provide a default database config for asset compilation #757](https://github.com/habitat-sh/core-plans/pull/757)
