# Register more than one site at a time with the sunet frontends.
#
# Example $sites (in YAML format):
#
#   sites:
#     - 'dev.idp.eduid.se':
#         frontends:
#           - 'se-fre-lb-1.sunet.se'
#         port: 5443
#
class sunet::frontend::register_sites_array(
  Array $sites,
) {
  file {
    '/usr/local/bin/sunetfrontend-register':
      ensure  => 'file',
      mode    => '0755',
      content => template('sunet/frontend/sunetfrontend-register.erb')
      ;
  }
  $sites.each | $site | {
    keys($site).each | $key | {
      $fe_str = join($site[$key]['frontends'], ' ')
      $port = $site[$key]['port']
      $extra_args = pick($site[$key]['extra_args'], ' ')
      $site_name = $key

      cron { "sunetfronted_register_sites_${site_name}_${port}":
        ensure  => present,
        command => "/usr/local/bin/sunetfrontend-register ${extra_args} ${site_name} ${port} ${fe_str} > /dev/null 2>&1",
        minute  => '*/3',
        require => File['/usr/local/bin/sunetfrontend-register'],
      }
    }
  }
}

