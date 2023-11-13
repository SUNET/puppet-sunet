# Set up nrpe server and some default checks
class sunet::nagios(
  String $nrpe_service    = 'nagios-nrpe-server',
  Integer $command_timeout = 60,
  String $loadw           = '15,10,5',
  String $loadc           = '30,25,20',
  Integer $procsw          = 150,
  Integer $procsc          = 200,
  Array[Optional[String]] $optout_checks = []
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

  unless 'dynamic_disk' in $optout_checks {
    sunet::nagios::nrpe_command {'check_dynamic_disk':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 15% -c 5% -W 15% -K 5% -X overlay -X aufs -X tmpfs -X devtmpfs -X nsfs -A -i "^/var/lib/docker/plugins/.*/propagated-mount|^/snap|^/var/snap|^/sys/kernel/debug/tracing"'
    }
  }
  unless 'users' in $optout_checks {
    sunet::nagios::nrpe_command {'check_users':
      command_line => '/usr/lib/nagios/plugins/check_users -w 5 -c 10'
    }
  }
  unless 'load' in $optout_checks {
    sunet::nagios::nrpe_command {'check_load':
      command_line => "/usr/lib/nagios/plugins/check_load -w ${loadw} -c ${loadc}"
    }
  }

  unless 'root' in $optout_checks {
    sunet::nagios::nrpe_command {'check_root':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 15% -c 5% -p /'
    }
  }

  unless 'boot' in $optout_checks {
    sunet::nagios::nrpe_command {'check_boot':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /boot'
    }
  }

  unless 'var' in $optout_checks {
    sunet::nagios::nrpe_command {'check_var':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /var'
    }
  }

  unless 'zombie_procs' in $optout_checks {
    sunet::nagios::nrpe_command {'check_zombie_procs':
      command_line => '/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z'
    }
  }

  unless 'total_procs_lax' in $optout_checks {
    if is_hash($facts) and has_key($facts, 'cosmos') and ('frontend_server' in $facts['cosmos']['host_roles']) {
      # There are more processes than normal on frontend hosts
      $_procw = $procsw + 350
      $_procc = $procsc + 350
    } else {
      $_procw = $procsw
      $_procc = $procsc
    }
    file { '/usr/lib/nagios/plugins/check_process' :
        ensure  => 'file',
        mode    => '0751',
        group   => 'nagios',
        require => Package['nagios-nrpe-server'],
        content => template('sunet/nagioshost/check_process.erb'),
    }
    sunet::nagios::nrpe_command {'check_total_procs_lax':
      command_line => "/usr/lib/nagios/plugins/check_procs -k -w ${_procw} -c ${_procc}"
    }
  }

  unless 'uptime' in $optout_checks {
    file { '/usr/lib/nagios/plugins/check_uptime.pl' :
        ensure  => 'file',
        mode    => '0751',
        group   => 'nagios',
        require => Package['nagios-nrpe-server'],
        content => template('sunet/nagioshost/check_uptime.pl.erb'),
    }
    sunet::nagios::nrpe_command {'check_uptime':
      command_line => '/usr/lib/nagios/plugins/check_uptime.pl -f'
    }
  }

  unless 'reboot' in $optout_checks {
    file { '/usr/lib/nagios/plugins/check_reboot' :
        ensure  => 'file',
        mode    => '0751',
        group   => 'nagios',
        require => Package['nagios-nrpe-server'],
        content => template('sunet/nagioshost/check_reboot.erb'),
    }
    sunet::nagios::nrpe_command {'check_reboot':
      command_line => '/usr/lib/nagios/plugins/check_reboot'
    }
  }

  unless 'status' in $optout_checks {
    sunet::nagios::nrpe_command {'check_status':
      command_line => '/usr/local/bin/check_status'
    }
  }

  unless 'mailq' in $optout_checks {
    sunet::nagios::nrpe_command {'check_mailq':
      command_line => '/usr/lib/nagios/plugins/check_mailq -w 20 -c 100'
    }
  }

  unless 'memory' in $optout_checks {
    if ($facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'],'22.04') >= 0 ) {
      $mem_arg = '-w 90% -c 95%'
    } elsif ($facts['os']['name'] == 'Debian' and versioncmp($facts['os']['release']['full'],'12') >= 0 ) {
      $mem_arg = '-w 90% -c 95%'
    } else {
      $mem_arg = '-w 10% -c 5%'
    }
    sunet::nagios::nrpe_command {'check_memory':
      command_line => "/usr/lib/nagios/plugins/check_memory ${mem_arg}"
    }
  }

  unless 'entropy' in $optout_checks {
    sunet::nagios::nrpe_command { 'check_entropy':
      command_line => '/usr/lib/nagios/plugins/check_entropy -w 256',
    }
  }

  unless 'ntp_time' in $optout_checks {
    sunet::nagios::nrpe_command { 'check_ntp_time':
      command_line => '/usr/lib/nagios/plugins/check_ntp_time -H localhost',
    }
  }

  unless 'scriptherder' in $optout_checks {
    sunet::nagios::nrpe_command { 'check_scriptherder':
      command_line => '/usr/local/bin/scriptherder --mode check',
    }
  }

  unless 'apt' in $optout_checks {
    sunet::nagios::nrpe_command { 'check_apt':
      command_line => '/usr/lib/nagios/plugins/check_apt-wrapper',
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
