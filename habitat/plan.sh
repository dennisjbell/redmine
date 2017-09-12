pkg_name=redmine
pkg_origin=starkandwayne
pkg_scaffolding="core/scaffolding-ruby"

pkg_version="0.1.0"
pkg_binds_optional=( [database]="port" )

pkg_deps=(core/imagemagick)

do_install() {
  export DATABASE_URL="postgresql://nobody@nowhere/fake_db_to_appease_rails_env"
  do_default_install
}
