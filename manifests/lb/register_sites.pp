# Register more than one site at a time with the sunet frontends.
#
# Example $sites (in YAML format):
#
#   sites:
#     'dev.idp.eduid.se':
#       frontends:
#         - 'se-fre-lb-1.sunet.se'
#       port: 5443
#
class sunet::lb::register_sites(
  Hash $sites,
) {
  file {
    '/usr/local/bin/sunetfrontend-register':
      ensure  => 'file',
      mode    => '0755',
      content => template('sunet/lb/sunetfrontend-register.erb')
      ;
  }

  keys($sites).each | $site | {
    $fe_str = join($sites[$site]['frontends'], ' ')
    $port = $sites[$site]['port']
    $extra_args = pick($sites[$site]['extra_args'], ' ')

    cron { "sunetfronted_register_sites_${site}":
      ensure  => present,
      command => "/usr/local/bin/sunetfrontend-register ${extra_args} ${site} ${port} ${fe_str} > /dev/null 2>&1",
      minute  => '*/3',
      require => File['/usr/local/bin/sunetfrontend-register'],
    }
  }
}
