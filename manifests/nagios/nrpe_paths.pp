# Distribution layout shared by NRPE and its individual check definitions.
class sunet::nagios::nrpe_paths {
  if $facts['os']['name'] == 'AlmaLinux' {
    $service = 'nrpe'
    $user = 'nrpe'
    $confdir = '/etc/nrpe.d'
    $plugins = '/usr/lib64/nagios/plugins'
  } else {
    $service = 'nagios-nrpe-server'
    $user = 'nagios'
    $confdir = '/etc/nagios/nrpe.d'
    $plugins = '/usr/lib/nagios/plugins'
  }
}
