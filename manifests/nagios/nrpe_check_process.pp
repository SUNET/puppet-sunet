
define nrpe_check_process ($display_name = undef) {
   $process_display_name = $alias ? {
      undef   => $name,
      default => $alias
   }
   sunet::nagios::nrpe_command {'check_process_pidfile':
     command_line => "/usr/lib/nagios/plugins/check_process -C PCPU -p $name -N $process_display_name"
   }
}
