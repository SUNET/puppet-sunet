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
)
{

  $hostname = $facts['networking']['fqdn']
  $cahash = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/ca.crt -noout -hash').chomp
  $cahash2 = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/geant-auth-ca.crt -noout -hash').chomp
  $cahash3 = generate('/bin/sh', '-c', '/usr/bin/openssl x509 -in /etc/puppet/cosmos-modules/sunet/files/xrootd/geant-trust-ca.crt -noout -hash').chomp

  if ($hostname in $managers ) {
    $role = 'manager'
  } else {
    $role = 'server'
  }
  # Config
  $xrootd_buckets = lookup('xrootd_buckets')
  $tls_key = lookup('tls_key')

  # Composefile
  sunet::docker_compose { 'xrootd':
    content          => template('sunet/xrootd/docker-compose.erb.yml'),
    service_name     => 'xrootd',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'XRootD S3 HTTP',
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
  }
  file { '/opt/xrootd/grid-security/certificates/ca.pem':
    ensure  => file,
    content => file('sunet/xrootd/ca.crt'),
  }
  file { "/opt/xrootd/grid-security/certificates/${cahash}.0":
    ensure  => link,
    target  => 'ca.pem'
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
  file { '/opt/xrootd/grid-security/xrd/xrdcert.pem':
    ensure  => file,
    content => file('sunet/xrootd/wildcard.drive.test.sunet.se.crt'),
  }
  file { '/opt/xrootd/grid-security/xrd/xrdkey.pem':
    ensure  => file,
    content => $tls_key,
    owner   => '996',
    group   => '996',
    mode    => "0400",
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
