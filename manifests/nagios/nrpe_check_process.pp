# Check process
define sunet::nagios::nrpe_check_process (
  $display_name = undef
) {

  file { '/usr/lib/nagios/plugins/check_process' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_process.erb'),
  }

  $process_display_name = $alias ? {
    undef   => $name,
    default => $alias
  }
  sunet::nagios::nrpe_command {"check_process_${name}":
    command_line => "/usr/lib/nagios/plugins/check_process -C PCPU -p ${name} -N ${process_display_name}"
  }
}
