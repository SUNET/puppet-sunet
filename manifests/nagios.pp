class sunet::nagios {

   $nagios_ip_v4 = hiera('nagios_ip_v4', '109.105.111.111')
   $nagios_ip_v6 = hiera('nagios_ip_v6', '2001:948:4:6::111')
   $allowed_hosts = "${nagios_ip_v4},${nagios_ip_v6}"

   package {'nagios-nrpe-server':
       ensure => 'installed',
   }
   service {'nagios-nrpe-server':
       ensure  => 'running',
       enable  => 'true',
       require => Package['nagios-nrpe-server'],
   }
   file { "/etc/nagios/nrpe.cfg" :
       notify  => Service['nagios-nrpe-server'],
       ensure  => 'file',
       mode    => '0640',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/nagioshost/nrpe.cfg.erb'),
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
