# SUNET Inventory Service
class sunet::invent(
  String  $invent_dir     = '/opt/invent',
  Integer $retention_days = 30,
) {
  $host_os = String($::facts['operatingsystem'], "%d")
  $awk = $host_os ? {
    alpine => gawk,
    default => awk,
  }
  $script_dir = "${invent_dir}/scripts"

  package { 'awk':
    ensure => installed,
    name   => $awk
  }
  -> package { 'jq':
    ensure => installed,
  }
  -> package { 'which':
    ensure => installed,
  }
  -> file { $invent_dir:
    ensure => directory,
  }
  -> file { $script_dir:
    ensure => directory,
  }
  -> file { "${script_dir}/invent.sh":
    content => template('sunet/invent/invent.sh.erb'),
  }
  -> sunet::scriptherder::cronjob { "${script_dir}/invent.sh":
    job_name => 'gather_inventory',
    user    => 'root',         
    minute  =>  '*/10',          
  }
}
