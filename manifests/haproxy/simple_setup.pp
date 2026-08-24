# Generate the simple most common haproxy setup we use
define sunet::haproxy::simple_setup(
  String  $content,
  String  $cert,
  String  $key,
  String  $server_name    = $facts['networking']['fqdn'],
  String  $port           = '443',
  Array   $allow_clients  = [],
  Integer $critical = 1296000, #in seconds
  Integer $warning = 864000,  #in seconds
) {
  ensure_resource(sunet::misc::system_user, 'haproxy', {group => 'haproxy' })

  ensure_resource(sunet::misc::certbundle, "${facts['networking']['fqdn']}_haproxy", {
    group     => 'haproxy',
    bundle    => ["cert=${cert}",
                  "key=${key}",
                  "out=private/${facts['networking']['fqdn']}_haproxy.crt",
                  ],
    })

  sunet::misc::create_root_dir { ["/opt/sunet/${name}",
                                  "/opt/sunet/${name}/etc",
                                  ]:
  }

  sunet::nagios::nrpe_command {"check_cert_expire_${name}":
    command_line => "/usr/lib/nagios/plugins/check_cert_expire -w ${warning} -c ${critical} ${facts['networking']['fqdn']}_haproxy"
  }

  $config = "/opt/sunet/${name}/etc/haproxy.cfg"
  concat { $config:
    owner => 'root',
    group => 'haproxy',
    mode  => '0640',
  }

  if ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '24.04') >= 0) {
    concat::fragment { "${name}_simple_haproxy_header":
      target  => $config,
      order   => '10',
      content => template('sunet/haproxy/simple_haproxy_base.cfg.erb'),
    }

    concat::fragment { "${name}_simple_haproxy_config":
      target  => $config,
      order   => '10000',
      content => $content,
    }
  } else {
    concat::fragment { "${name}_simple_haproxy_header":
      target  => $config,
      order   => '10000',
      content => template('sunet/haproxy/simple_haproxy_base.cfg.erb'),
    }

    concat::fragment { "${name}_simple_haproxy_config":
      target  => $config,
      order   => '10',
      content => $content,
    }
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { $name :
      allow_clients => flatten($allow_clients),
      port          => $port,
    }
  } else {
    sunet::misc::ufw_allow { "${name}_allow_clients":
      from => $allow_clients,
      to   => 'any',
      port => $port,
    }
  }
}
