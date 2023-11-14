# The class to setup Nagios NRPE
class sunet::nagios::nrpe(
  String $nrpe_service    = 'nagios-nrpe-server',
  Integer $command_timeout = 60,
  String $loadw           = '15,10,5',
  String $loadc           = '30,25,20',
  Integer $procsw          = 150,
  Integer $procsc          = 200,
  Array[Optional[String]] $checks = [],

) {

  $nagios_ip_v4 = lookup('nagios_ip_v4', undef, undef, '109.105.111.111')
  $nagios_ip_v6 = lookup('nagios_ip_v6', undef, undef, '2001:948:4:6::111')
  $nrpe_clients = lookup('nrpe_clients', undef, undef, ['127.0.0.1','127.0.1.1',$nagios_ip_v4,$nagios_ip_v6])
  $allowed_hosts = join($nrpe_clients,',')

  package {$nrpe_service:
      ensure => 'installed',
  }
  -> service {$nrpe_service:
      ensure  => 'running',
      enable  => 'true',
      require => Package[$nrpe_service],
  }

  package {'monitoring-plugins-contrib':
      ensure => 'installed',
  }

  concat {'/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg':
      owner  => root,
      group  => root,
      mode   => '0644',
      notify => Service[$nrpe_service]
  }
  concat::fragment {'sunet_nrpe_commands':
      target  => '/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg',
      content => '# Do not edit by hand - maintained by puppet',
      order   => '10',
      notify  => Service[$nrpe_service]
  }
  file { '/etc/nagios/nrpe.cfg' :
      ensure  => 'file',
      notify  => Service[$nrpe_service],
      mode    => '0640',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/nrpe.cfg.erb'),
  }

  checks.each |$check| {
    "sunet::nagios::${check}" { "nagios-nrpe-${check}": }

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
