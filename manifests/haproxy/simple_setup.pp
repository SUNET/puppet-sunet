# Generate the simple most common haproxy setup we use
define sunet::haproxy::simple_setup(
  String $content,
  String $cert,
  String $key,
  String $server_name    = $facts['networking']['fqdn'],
  String $port           = '443',
  Array  $allow_clients  = [],
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

  $config = "/opt/sunet/${name}/etc/haproxy.cfg"
  concat { $config:
    owner => 'root',
    group => 'haproxy',
    mode  => '0640',
  }

  if ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '24.04') >= 0) {
    notice("---------- >= 24")
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

  sunet::misc::ufw_allow { "${name}_allow_clients":
    from => $allow_clients,
    to   => 'any',
    port => $port,
  }
}
