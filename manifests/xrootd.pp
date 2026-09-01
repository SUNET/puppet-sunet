# Postfix for SUNET
class sunet::xrootd(
  Array[Hash] $cms_allow_hosts,
  Array       $managers,
  String      $manager_domain,
  String      $cms_port                 = '1213',
  String      $container_image          = 'docker.sunet.se/staas/xrootd-s3-http',
  String      $container_tag            = '0.4.1-1',
  String      $export                   = '/',
  String      $interface                = 'ens3',
  String      $xrootd_port              = '1094',
  String      $xrootd_admin_path        = '/var/spool/xrootd',
  Boolean     $tpc                      = false,
  Enum['http','xroot','both'] $tpc_mode = 'both',
  Boolean     $tpc_chksum               = false,
  # Name dehydrated fetched the certificate under. Left undef, managers use
  # $manager_domain and data servers their own FQDN — the managers share one
  # certificate covering the xrdm alias, which is the name clients connect to.
  Optional[String] $cert_domain         = undef,
  # ACME HTTP-01 responder on port 80. On by default because without it this node
  # cannot obtain a certificate, and without a certificate xrootd will not start.
  Boolean     $acme_responder           = true,
  String      $acme_server              = 'acme-c.sunet.se',
  String      $haproxy_image            = 'docker.sunet.se/library/haproxy',
  String      $haproxy_tag              = 'stable',
  # Where to find trust anchors the ACME chain stops short of.
  String      $system_certdir           = '/etc/ssl/certs',
)
{

  $hostname = $facts['networking']['fqdn']
  $cahash = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/harica-ca-root.crt -noout -hash').chomp
  $cahash2 = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/geant-auth-ca.crt -noout -hash').chomp
  $cahash3 = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/geant-trust-ca.crt -noout -hash').chomp
  $cahash4 = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/geant-tls.crt -noout -hash').chomp

  if ($hostname in $managers ) {
    $role = 'manager'
  } else {
    $role = 'server'
  }
  # Config
  $xrootd_buckets = lookup('xrootd_buckets')

  # TLS material comes from dehydrated, as it does for imap, smtp and calendar.
  # It used to be a certificate committed to this module plus a key in eyaml,
  # which left it outside every renewal path; it expired unnoticed on 2026-06-24.
  # fullchain rather than cert.pem so peers are sent the intermediate.
  $_cert_domain = $cert_domain ? {
    undef   => $role ? { 'manager' => $manager_domain, default => $hostname },
    default => $cert_domain,
  }
  $acme_dir = "/etc/dehydrated/certs/${_cert_domain}"
  $acme_cert = "${acme_dir}/fullchain.pem"
  $acme_key = "${acme_dir}/privkey.pem"
  $acme_chain = "${acme_dir}/chain.pem"
  $certdir = '/opt/xrootd/grid-security/certificates'

  # The define rather than sunet::dehydrated::client: that class takes a single
  # $domain and cannot be re-instantiated, so one cosmos-rules regex covering all
  # five nodes could not give each its own certificate name.
  sunet::dehydrated::client_define { "domain_${_cert_domain}":
    domain          => $_cert_domain,
    single_domain   => false,
    ssl_links       => false,
    check_cert_port => $xrootd_port,
  }

  # Composefile
  sunet::docker_compose { 'xrootd':
    content          => template('sunet/xrootd/docker-compose.erb.yml'),
    service_name     => 'xrootd',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'XRootD S3 HTTP',
  }
  if $acme_responder {
    file { '/opt/xrootd/acme':
      ensure => directory,
    }
    file { '/opt/xrootd/acme/haproxy.cfg':
      ensure  => file,
      content => template('sunet/xrootd/haproxy-acme.cfg.erb'),
      # Bind-mounted into the container, so a change needs a restart to take.
      notify  => Service['sunet-xrootd'],
    }
    # Port 80 must be open to the world: Let's Encrypt validates from outside,
    # and for the managers it may validate the shared xrdm alias against either
    # host, so both have to answer.
    sunet::nftables::docker_expose { 'acme_http_80':
      allow_clients => 'any',
      port          => '80',
      iif           => $interface,
    }
  }
  sunet::nftables::docker_expose { "xrootd_port_${xrootd_port}":
    allow_clients => 'any',
    port          => $xrootd_port,
    iif           => $interface,
  }
  $cms_ports = $cms_port
  $cms_allow_hosts.each |$host| {
    sunet::nftables::docker_expose { "cms_ports_${host['name']}":
      allow_clients => [$host['ipv4'], $host['ipv6']],
      port          => $cms_ports,
      iif           => $interface,
    }
  }
  file { '/opt/xrootd/config':
    ensure => directory,
    owner  => '996',
    group  => '996',
  }
  file { '/opt/xrootd/admin':
    ensure  => directory,
    recurse => true,
    owner   => '996',
    group   => '996',
  }
  file { '/opt/xrootd/grid-security/xrd':
    ensure => directory,
    owner  => '996',
    group  => '996',
  }
  file { '/opt/xrootd/grid-security/certificates':
    ensure => directory,
    owner  => '996',
    group  => '996',
  }
  file { '/opt/xrootd/config/xrootd.cfg':
    ensure  => file,
    content => template("sunet/xrootd/xrootd-${role}.cfg.erb"),
  }
  file { '/opt/xrootd/config/Authfile':
    ensure  => file,
    content => file('sunet/xrootd/Authfile'),
  }
  file { '/opt/xrootd/grid-security/grid-mapfile':
    ensure  => file,
    content => file('sunet/xrootd/grid-mapfile'),
    # GSI loads the map at startup and caches entries for 600s; unlike the
    # Authfile (acc.authrefresh 60) it is not re-read on its own.
    notify  => Service['sunet-xrootd'],
  }
  file { '/opt/xrootd/grid-security/certificates/harica-ca-root.crt':
    ensure  => file,
    content => file('sunet/xrootd/harica-ca-root.crt'),
  }
  file { "/opt/xrootd/grid-security/certificates/${cahash}.0":
    ensure  => link,
    target  => 'harica-ca-root.crt'
  }
  file { '/opt/xrootd/grid-security/certificates/geant-auth-ca.crt':
    ensure  => file,
    content => file('sunet/xrootd/geant-auth-ca.crt'),
  }
  file { "/opt/xrootd/grid-security/certificates/${cahash2}.0":
    ensure  => link,
    target  => 'geant-auth-ca.crt'
  }
  file { '/opt/xrootd/grid-security/certificates/geant-trust-ca.crt':
    ensure  => file,
    content => file('sunet/xrootd/geant-trust-ca.crt'),
  }
  file { "/opt/xrootd/grid-security/certificates/${cahash3}.0":
    ensure  => link,
    target  => 'geant-trust-ca.crt'
  }
  file { '/opt/xrootd/grid-security/certificates/geant-tls.crt':
    ensure  => file,
    content => file('sunet/xrootd/geant-tls.crt'),
  }
  file { "/opt/xrootd/grid-security/certificates/${cahash4}.0":
    ensure  => link,
    target  => 'geant-tls.crt'
  }
  # Copied rather than symlinked: the container only bind-mounts
  # /opt/xrootd/grid-security, and it runs as uid 996, which cannot read
  # dehydrated's root-owned key. XRootD reads xrd.tls once at startup, so the
  # service is notified to pick up a renewal.
  # links => follow is load-bearing: dehydrated's fullchain.pem and privkey.pem are
  # relative symlinks to versioned files, and without it puppet copies the link
  # rather than its content, leaving a dangling link here. Modes are explicit so
  # the source's 0600 root is not inherited; 996 is the container's xrootd uid.
  if find_file($acme_cert) and find_file($acme_key) {
    file { '/opt/xrootd/grid-security/xrd/xrdcert.pem':
      ensure => file,
      source => $acme_cert,
      links  => follow,
      owner  => '996',
      group  => '996',
      mode   => '0444',
      notify => Service['sunet-xrootd'],
    }
    file { '/opt/xrootd/grid-security/xrd/xrdkey.pem':
      ensure => file,
      source => $acme_key,
      links  => follow,
      owner  => '996',
      group  => '996',
      mode   => '0400',
      notify => Service['sunet-xrootd'],
    }
  } else {
    notify { "xrootd: no dehydrated certificate at ${acme_dir}, TLS will not start":
      loglevel => 'warning',
    }
  }
  # GSI refuses to initialise unless the issuing CA of our own server certificate
  # is present here with hash links, and Let's Encrypt is not in the IGTF bundle
  # this directory otherwise holds. Install the chain dehydrated delivered with the
  # certificate and derive the links from it.
  if find_file($acme_chain) {
    file { "${certdir}/acme-chain.pem":
      ensure => file,
      source => $acme_chain,
      links  => follow,
      mode   => '0444',
      notify => Exec['xrootd: acme ca links'],
    }
    file { '/usr/local/bin/xrootd-acme-ca-links.sh':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/xrootd/acme-ca-links.sh.erb'),
      notify  => Exec['xrootd: acme ca links'],
    }
    exec { 'xrootd: acme ca links':
      command     => '/usr/local/bin/xrootd-acme-ca-links.sh',
      refreshonly => true,
      notify      => Service['sunet-xrootd'],
    }
  }
  $xrootd_buckets.each |$bucket| {
    file { "/opt/xrootd/config/${bucket['name']}":
      ensure => directory,
    }
    file { "/opt/xrootd/config/${bucket['name']}/access-key":
      ensure  => file,
      content => $bucket['access_key'],
    }
    file { "/opt/xrootd/config/${bucket['name']}/secret-key":
      ensure  => file,
      content => $bucket['secret_key'],
    }
  }

}
