define sunet::nagios::nrpe_check_dns_zone ($display_name = undef) {
   file { '/usr/lib/nagios/plugins/check_dns_zone.pl':
       ensure  => 'file',
       mode    => '0755',
       group   => 'nagios',
       require => Package['nagios-nrpe-server'],
       content => template('sunet/ipam/check_dns_zone.pl.erb'),
   }
   sunet::nagios::nrpe_command {"check_${title}":
     command_line => "/usr/lib/nagios/plugins/check_dns_zone.pl"
   }
}
