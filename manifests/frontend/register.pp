# Register a site with one or more sunet-frontends
define sunet::frontend::register(
  String  $site,
  Array   $frontends,
  Integer $port = 443,
) {
  $fe_str = join($frontends, ' ')

  file {
    "/usr/local/bin/sunetfrontend-register":
      ensure  => 'file',
      mode    => '0755',
      content => template("sunet/frontend/sunetfrontend-register.erb")
      ;
  } ->

  cron { "sunetfronted_register_${site}":
    ensure   => present,
    command  => "/usr/local/bin/sunetfrontend-register ${site} ${port} $fe_str > /dev/null 2>&1",
    minute   => '*/3',
  }
}
