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
