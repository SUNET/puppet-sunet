# Install docker from https://get.docker.com/ubuntu
class sunet::dockerhost(
  String $docker_version = "1.8.3-0~${::lsbdistcodename}",
) {

  # Remove old versions, if installed
  package { ['lxc-docker-1.6.2', 'lxc-docker'] :
     ensure => 'purged',
  } ->

  file {'/etc/apt/sources.list.d/docker.list':
     ensure => 'absent',
  }

  apt::source {'docker_official':
     location    => 'https://apt.dockerproject.org/repo',
     release     => "ubuntu-${::lsbdistcodename}",
     repos       => 'main',
     key         => '2C52609D',
     include_src => false
  } ->

  package { 'docker-engine' :
     ensure => $docker_version,
  } ->

  class {'docker':
     manage_package              => false,
     use_upstream_package_source => false,
  } ->
  package { 'unbound': ensure => 'latest' } ->
  service { 'unbound': ensure => 'running' }
  
  file { '/usr/local/etc/docker.d': ensure => 'directory' } ->
  file { '/usr/local/etc/docker.d/20unbound':
    ensure  => file,
    path    => '/usr/local/etc/docker.d/20unbound',
    mode    => '0755',
    content => template('sunet/dockerhost/20unbound.erb'),
  }

  file { '/etc/unbound/unbound.conf.d/docker.conf':
    ensure  => file,
    path    => '/etc/unbound/unbound.conf.d/docker.conf',
    mode    => '0644',
    content => template('sunet/dockerhost/unbound_docker.conf.erb'),
    require => Package['unbound'],
    notify  => Service['unbound'],
  }

  ensure_resource('file','/etc/logrotate.d',{ ensure => directory })
  file { '/etc/logrotate.d/docker-containers':
    ensure  => file,
    path    => '/etc/logrotate.d/docker-containers',
    mode    => '0644',
    content => template('sunet/dockerhost/logrotate_docker-containers.erb'),
  }

  ufw::allow { 'allow-docker-resolving_udp':
    port  => '53',
    ip    => $::ipaddress_docker0,    # both IPv4 and IPv6
    from  => '172.16.0.0/12',
    proto => 'udp',
  }
  ufw::allow { 'allow-docker-resolving_tcp':
    port  => '53',
    ip    => $::ipaddress_docker0,    # both IPv4 and IPv6
    from  => '172.16.0.0/12',
    proto => 'tcp',
  }

}
