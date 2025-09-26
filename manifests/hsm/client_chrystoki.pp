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

  #$hsm_servers.each  | $hsm | {

  #  file { "/usr/safenet/lunaclient/cert/server/${hsm}Cert.pem":
  #    ensure  => 'file',
  #    content => file("sunet/hsm/servers/${hsm}Cert.pem")
  #  }

  #   concat::fragment { $hsm:
  #    target  => '/usr/safenet/lunaclient/cert/server/CAFile.pem',
  #    content => file("sunet/hsm/servers/${hsm}Cert.pem")
  #  }
  #}

  #$conf_dir = '/etc/Chrystoki.conf.d/'
  #if (find_file($conf_dir)){
  #  dir_glob(["${conf_dir}/*.conf"]).each |String $file| {
  #    concat::fragment { $file:
  #      target => '/etc/Chrystoki.conf',
  #      source => $file,
  #    }
  #  }
  #}
}
