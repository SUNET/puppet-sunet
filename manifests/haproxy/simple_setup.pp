# Generate the simple most common haproxy setup we use
define sunet::haproxy::simple_setup(
  String $content,
  String $cert,
  Strung $key,
  String $server_name    = $::fqdn,
  String $port           = '443',
  Array  $allow_clients  = [$facts['cosmos']['frontend_server_addrs'],
                            $facts['cosmos']['monitor_server_addrs'],
                            ],
) {
  ensure_resource(sunet::misc::system_user, 'haproxy', {group => 'haproxy' })

  ensure_resource(sunet::misc::certbundle, "${::fqdn}_haproxy", {
    group     => 'haproxy',
    bundle    => ["cert=${cert}",
                  "key=${key}",
                  "out=private/${::fqdn}_haproxy.crt",
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

  sunet::misc::ufw_allow { "${name}_allow_clients":
    from => $allow_clients,
    to   => 'any',
    port => $port,
  }
}
