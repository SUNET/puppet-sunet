define sunet::frontend::load_balancer::website(
  Array            $frontends,
  Hash             $backends,
  String           $basedir,
  String           $confdir,
  Optional[String] $frontend_template = undef,
  Hash             $frontend_template_params = {},
  Array            $allow_ports = [],
  Optional[String] $letsencrypt_server = undef,
  Array            $backend_haproxy_config = [],  # used in 'haproxy-backend-config'
) {
  $_ipv4 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 4) }
  }
  $_ipv6 = map($frontends) |$fe| {
    $fe['primary_ips'].filter |$ip| { is_ipaddr($ip, 6) }
  }
  # avoid lists in list
  $ipv4 = flatten($_ipv4)
  $ipv6 = flatten($_ipv6)

  # There doesn't seem to be a function to just get the index of an
  # element in an array in Puppet, so we iterate over all the elements in
  # $frontends until we find our fqdn
  each($frontends) |$index, $fe| {
    if $fe['fqdn'] == $::fqdn {
      sunet::exabgp::monitor::haproxy { $name:
        ipv4  => $ipv4,
        ipv6  => $ipv6,
        index => $index + 1,
      }
    } else {
      $fe_fqdn = $fe['fqdn']
      debug("No match on frontend name $fe_fqdn (my fqdn $::fqdn)")
    }
  }

  sunet::frontend::load_balancer::website_backends { $name :
    backends               => $backends,
    basedir                => $basedir,
    confdir                => $confdir,
    backend_haproxy_config => $backend_haproxy_config,
  }

  if $frontend_template != undef {
    $server_name = $name
    $params = $frontend_template_params
    if has_key($tls_certificates, 'snakeoil') {
      $snakeoil = $tls_certificates['snakeoil']['bundle']
    }
    if has_key($tls_certificates, $name) {
      # Site name found in tls_certificates - good start
      $_tls_certificate_bundle = pick(
        $tls_certificates[$name]['haproxy'],
        $tls_certificates[$name]['certkey'],
        $tls_certificates[$name]['infra_certkey'],
        $tls_certificates[$name]['bundle'],
        $tls_certificates[$name]['dehydrated_bundle'],
        'NOMATCH',
      )
      if $_tls_certificate_bundle != 'NOMATCH' {
        $tls_certificate_bundle = $_tls_certificate_bundle
      } else {
        $_site_certs = $tls_certificates[$name]
        notice("None of the certificates for site ${name} matched my list (haproxy, certkey, infra_certkey, bundle): $_site_certs")
        if $snakeoil {
          $tls_certificate_bundle = $snakeoil
        }
      }
    } elsif $snakeoil {
      $tls_certificate_bundle = $snakeoil
    }

    if $snakeoil and $tls_certificate_bundle == $snakeoil {
      notice("Using snakeoil certificate for site ${name}")
    }
    # Note that haproxy actually does _not_ want IPv6 addresses to be enclosed by brackets.
    $ips = $ipv4 + $ipv6
    concat::fragment { "${name}_haproxy_frontend":
      target   => "${basedir}/haproxy/etc/haproxy-frontends.cfg",
      order    => '20',
      content  => template($frontend_template),
    }
  }

  # Add the IP addresses to the list of addresses that will get added to the loopback
  # interface before haproxy starts
  $ip_addr_add = ["# website ${name}",
                  map($ipv4 + $ipv6) | $ip | { "ip addr add ${ip} dev lo" },
                  "\n",
                  ]
  concat::fragment { "${name}_haproxy-pre-start_${name}":
    target   => "${basedir}/haproxy/scripts/haproxy-pre-start.sh",
    order    => '20',
    content  => $ip_addr_add.join("\n"),
  }

  if $allow_ports != [] {
    sunet::misc::ufw_allow { "load_balancer_${name}_allow_ports":
      from => 'any',
      to   => [$ipv4, $ipv6],
      port => $allow_ports,
    }
  }

  if $letsencrypt_server != undef and $letsencrypt_server != $::fqdn {
    sunet::dehydrated::client_define { $name :
      domain        => $name,
      server        => $letsencrypt_server,
      ssh_id        => 'acme_c',  # use shared key for all certs (Hiera key acme_c_ssh_key)
      single_domain => false,
    }
  }
}
