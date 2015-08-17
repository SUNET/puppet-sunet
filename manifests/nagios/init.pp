class sunet::nagios($nrpe_service = 'nagios-nrpe-server') {

   $nagios_ip_v4 = hiera('nagios_ip_v4', '109.105.111.111')
   $nagios_ip_v6 = hiera('nagios_ip_v6', '2001:948:4:6::111')
   $allowed_hosts = "${nagios_ip_v4},${nagios_ip_v6}"

   package {$nrpe_service:
       ensure => 'latest',
   } ->
   service {$nrpe_service:
       ensure  => 'running',
       enable  => 'true',
       require => Package[$nrpe_service],
   }
   concat {"/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg":
       owner => root,
       group => root,
       mode  => '0644'
   } 
   concat::fragment {"sunet_nrpe_commands":
       target  => "/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg",
       content => "# Do not edit by hand - maintained by puppet",
       order   => '10',
       notify  => $nrpe_service
   }
   file { "/etc/nagios/nrpe.cfg" :
       notify  => Service['nagios-nrpe-server'],
       ensure  => 'file',
       mode    => '0640',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/nrpe.cfg.erb'),
   }
   sunet::nagios::nrpe_command {'check_users': 
      command_line => '/usr/lib/nagios/plugins/check_users -w 5 -c 10'
   }
   sunet::nagios::nrpe_command {'check_load': 
      command_line => '/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20'
   }
   sunet::nagios::nrpe_command {'check_root': 
      command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /'
   }
   sunet::nagios::nrpe_command {'check_boot':
      command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /boot'
   }
   sunet::nagios::nrpe_command {'check_zombie_procs':
      command_line => '/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z'
   }
   sunet::nagios::nrpe_command {'check_total_procs':
      command_line => '/usr/lib/nagios/plugins/check_procs -w 150 -c 200'
   }
   sunet::nagios::nrpe_command {'check_uptime':
      command_line => '/usr/lib/nagios/plugins/check_uptime.pl -f'
   }
   sunet::nagios::nrpe_command {'check_reboot':
      command_line => '/usr/lib/nagios/plugins/check_reboot'
   }
   sunet::nagios::nrpe_command {'check_mailq':
      command_line => '/usr/lib/nagios/plugins/check_mailq -w 20 -c 100'
   }
   file { "/usr/lib/nagios/plugins/check_uptime.pl" :
       ensure  => 'file',
       mode    => '0751',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/check_uptime.pl.erb'),
   }
   file { "/usr/lib/nagios/plugins/check_reboot" :
       ensure  => 'file',
       mode    => '0751',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/check_reboot.erb'),
   }
   ufw::allow { "allow-nrpe-v4":
       from  => "${nagios_ip_v4}",
       ip    => 'any',
       proto => 'tcp',
       port  => 5666
   }
   ufw::allow { "allow-nrpe-v6":
       from  => "${nagios_ip_v6}",
       ip    => 'any',
       proto => 'tcp',
       port  => 5666
   }
}
