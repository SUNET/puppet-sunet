# The class to setup Nagios NRPE
class sunet::nagios::nrpe(
  String $nrpe_service    = $facts['os']['name'] ? { 'AlmaLinux' => 'nrpe', default => 'nagios-nrpe-server' },
  Integer $command_timeout = 60,
  String $loadw           = '15,10,5',
  String $loadc           = '30,25,20',
  Integer $procsw          = 150,
  Integer $procsc          = 200,
  Array[Optional[String]] $checks = [],

) {

  include sunet::nagios::nrpe_paths
  $nrpe_user = $sunet::nagios::nrpe_paths::user
  $confdir = $sunet::nagios::nrpe_paths::confdir
  $commands = "${confdir}/sunet_nrpe_commands.cfg"
  $override_dir = "/etc/systemd/system/${nrpe_service}.service.d"

  $nagios_ip_v4 = lookup('nagios_ip_v4', undef, undef, '109.105.111.111')
  $nagios_ip_v6 = lookup('nagios_ip_v6', undef, undef, '2001:948:4:6::111')
  $nrpe_clients = lookup('nrpe_clients', undef, undef, ['127.0.0.1','127.0.1.1',$nagios_ip_v4,$nagios_ip_v6])
  $allowed_hosts = join($nrpe_clients,',')

  # Only the Debian APT check needs access to the host's temporary directory.
  $override_ensure = $facts['os']['name'] ? {
    'AlmaLinux' => absent,
    default     => file,
  }
  file { $override_dir:
    ensure => directory,
  }
  exec { "${name}_daemon_reload":
    command     => '/usr/bin/systemctl daemon-reload',
    refreshonly => true,
  }

  file {
    "${override_dir}/privatetmp.conf":
      ensure  => $override_ensure,
      mode    => '0444',
      content => template('sunet/nagioshost/systemd-override-privatetmp.conf.erb'),
      require => Package[$nrpe_service],
      notify  =>  [Exec["${name}_daemon_reload"],Service[$nrpe_service]],
  }

  package {$nrpe_service:
      ensure => 'installed',
  }
  -> service {$nrpe_service:
      ensure  => 'running',
      enable  => 'true',
      require => Package[$nrpe_service],
  }

  if $facts['os']['name'] == 'AlmaLinux' {
    ensure_packages(['epel-release'])
    $plugins = ['nagios-plugins', 'nagios-plugins-disk', 'nagios-plugins-load', 'nagios-plugins-ntp', 'nagios-plugins-users', 'nagios-plugins-procs']
    ensure_packages($plugins)
    Package['epel-release'] -> Package[$plugins]
    Package['epel-release'] -> Package[$nrpe_service]
  } else {
    package { 'monitoring-plugins-contrib': ensure => installed }
  }

  concat { $commands:
      require => Package[$nrpe_service],
      owner  => root,
      group  => root,
      mode   => '0644',
      notify => Service[$nrpe_service]
  }
  concat::fragment {'sunet_nrpe_commands':
      target  => $commands,
      content => "# Do not edit by hand - maintained by puppet\n",
      order   => '10',
      notify  => Service[$nrpe_service]
  }
  # EPEL installs the NRPE policy during the first catalog. The agent's
  # cached pre-installation file contexts would otherwise select etc_t.
  $config_type = $facts['os']['name'] ? {
    'AlmaLinux' => 'nrpe_etc_t',
    default     => undef,
  }
  file { '/etc/nagios/nrpe.cfg' :
      ensure  => 'file',
      notify  => Service[$nrpe_service],
      mode    => '0640',
      group   => $nrpe_user,
      seltype => $config_type,
      require => Package[$nrpe_service],
      content => template('sunet/nagioshost/nrpe.cfg.erb'),
  }

  if $nrpe_service != $sunet::nagios::nrpe_paths::service {
    Package[$nrpe_service] { alias => $sunet::nagios::nrpe_paths::service }
    Service[$nrpe_service] { alias => $sunet::nagios::nrpe_paths::service }
  }

  $checks.each |$check| {
    ensure_resource("sunet::nagios::${check}", "nagios-nrpe-${check}")
  }

  $nrpe_clients.each |$client| {
    $client_name = regsubst($client,'([.:]+)','_','G')
    sunet::misc::ufw_allow { "allow-nrpe-${client_name}":
      from  => $client,
      proto => 'tcp',
      port  => '5666',
    }
  }
}
