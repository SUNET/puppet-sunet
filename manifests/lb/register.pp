# Register a site with one or more sunet-frontends
define sunet::lb::register(
  String  $site,
  Array   $frontends,
  Integer $port = 443,
  String  $extra_args = '',
) {
  $fe_str = join($frontends, ' ')

  file {
    '/usr/local/bin/sunetfrontend-register':
      ensure  => 'file',
      mode    => '0755',
      content => template('sunet/lb/sunetfrontend-register.erb')
      ;
  } ->

  cron { "sunetfronted_register_${site}":
    ensure  => present,
    command => "/usr/local/bin/sunetfrontend-register ${extra_args} ${site} ${port} ${fe_str} > /dev/null 2>&1",
    minute  => '*/3',
  }
}
