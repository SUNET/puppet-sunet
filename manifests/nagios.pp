# nagios
class sunet::nagios(
  $nrpe_service    = 'nagios-nrpe-server',
  $command_timeout = 60,
  $loadw           = '15,10,5',
  $loadc           = '30,25,20',
  $procsw          = 150,
  $procsc          = 200,
  $uptimew         = 30,
  $uptimec         = 50,
) {

  $nagios_ip_v4 = lookup('nagios_ip_v4', undef, undef, '109.105.111.111')
  $nagios_ip_v6 = lookup('nagios_ip_v6', undef, undef, '2001:948:4:6::111')
  $nrpe_clients = lookup('nrpe_clients', undef, undef, ['127.0.0.1','127.0.1.1',$nagios_ip_v4,$nagios_ip_v6])
  #$allowed_hosts = "127.0.0.1,127.0.1.1,${nagios_ip_v4},${nagios_ip_v6}"
  $allowed_hosts = join($nrpe_clients,',')

  notice('"sunet::nagios" is deprecated - please migrate to "sunet::nagios::nrpe" instead')

  package {$nrpe_service:
      ensure => 'installed',
  }
  -> service {$nrpe_service:
      ensure  => 'running',
      enable  => 'true',
      require => Package[$nrpe_service],
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

  sunet::nagios::nrpe_command {'check_dynamic_disk':
    command_line => '/usr/lib/nagios/plugins/check_disk -w 15% -c 5% -W 15% -K 5% -X overlay -X aufs -X tmpfs -X devtmpfs -X nsfs -A -i "^/var/lib/docker/plugins/.*/propagated-mount|^/snap|^/var/snap|^/sys/kernel/debug/tracing"'
  }
  sunet::nagios::nrpe_command {'check_users':
    command_line => '/usr/lib/nagios/plugins/check_users -w 5 -c 10'
  }
  sunet::nagios::nrpe_command {'check_load':
    command_line => "/usr/lib/nagios/plugins/check_load -w ${loadw} -c ${loadc}"
  }
  if $facts['networking']['fqdn'] == 'docker.sunet.se' {
    sunet::nagios::nrpe_command {'check_root':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 4% -c 2% -p /'
    }
  } else {
    sunet::nagios::nrpe_command {'check_root':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 15% -c 5% -p /'
    }
  }
  sunet::nagios::nrpe_command {'check_boot':
    command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /boot'
  }
  if $facts['networking']['fqdn'] == 'docker.sunet.se' {
    sunet::nagios::nrpe_command {'check_var':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 4% -c 2% -p /var'
    }
  } else {
    sunet::nagios::nrpe_command {'check_var':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /var'
    }
  }
  sunet::nagios::nrpe_command {'check_zombie_procs':
    command_line => '/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z'
  }
  if $facts =~ Hash and 'cosmos' in $facts and ('frontend_server' in $facts['cosmos']['host_roles']) {
    # There are more processes than normal on frontend hosts
    $_procw = $procsw + 350
    $_procc = $procsc + 350
  } else {
    $_procw = $procsw
    $_procc = $procsc
  }
  sunet::nagios::nrpe_command {'check_total_procs_lax':
    command_line => "/usr/lib/nagios/plugins/check_procs -k -w ${_procw} -c ${_procc}"
  }
  sunet::nagios::nrpe_check_uptime { 'check_uptime':
    uptimew =>  $uptimew,
    uptimec =>  $uptimec,
  }
  sunet::nagios::nrpe_command {'check_reboot':
    command_line => '/usr/lib/nagios/plugins/check_reboot'
  }
  sunet::nagios::nrpe_command {'check_status':
    command_line => '/usr/local/bin/check_status'
  }
  sunet::nagios::nrpe_command {'check_mailq':
    command_line => '/usr/lib/nagios/plugins/check_mailq -w 20 -c 100'
  }
  file { '/usr/lib/nagios/plugins/check_reboot' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_reboot.erb'),
  }
  if ($facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['major'] == '16.04') {
    file { '/usr/lib/nagios/plugins/check_memory':
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_memory_patched_806598.erb'),
    }
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
