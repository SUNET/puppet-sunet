# The HSM client trust  fabric
define sunet::hsm::client_chrystoki (
  Array   $hsm_servers,
) {

  concat { '/etc/Chrystoki.conf':
    ensure_newline => true,
  }

  $me = $facts['networking']['fqdn']
  concat::fragment { 'chrystoki_base':
    target  => '/etc/Chrystoki.conf',
    content => template('sunet/hsm/chrystoki.conf-base.erb'),
    order   => '01'
  }

  $conf_dir = '/etc/Chrystoki.conf.d/'
  if (find_file($conf_dir)){
    dir_glob(["${conf_dir}/*.conf"]).each |String $file| {
      concat::fragment { $file:
        target => '/etc/Chrystoki.conf',
        source => $file,
      }
    }
  }
}
