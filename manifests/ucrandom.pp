# Random entropy client
define sunet::ucrandom(
  $ensure = 'present',
  $port   = '4711',
  $device = '/dev/random',
) {
  $ensure_file = $ensure ? {
    'present' => 'file',
    'absent'  => 'absent',
  }
  file {'/usr/bin/ucrandom':
      ensure  => $ensure_file,
      owner   => root,
      group   => root,
      mode    => '0755',
      content => template('sunet/ucrandom/ucrandom.erb')
  }
  file {'/etc/default': ensure => directory }
  file {'/etc/default/ucrandom':
      ensure  => $ensure_file,
      owner   => root,
      group   => root,
      mode    => '0660',
      content => template('sunet/ucrandom/default.erb')
  }
  case $facts['init_type'] {
      'upstart': {
        file {'/etc/init/ucrandom.conf':
          ensure  => $ensure_file,
          owner   => root,
          group   => root,
          mode    => '0660',
          content => template('sunet/ucrandom/ucrandom.conf.erb')
        }
      }
      'systemd-sysv': {
        file {'/lib/systemd/system/ucrandom.service':
          ensure  => $ensure_file,
          owner   => root,
          group   => root,
          mode    => '0600',
          content => template('sunet/ucrandom/ucrandom.unit.erb')
        }
      }
      default: {
        file {'/lib/systemd/system/ucrandom.service':
          ensure  => $ensure_file,
          owner   => root,
          group   => root,
          mode    => '0600',
          content => template('sunet/ucrandom/ucrandom.unit.erb')
        }
      }
  }
  $_provider = $facts['init_type'] ? {
      'upstart'      => 'upstart',
      'systemd-sysv' => 'systemd',
      default        => 'debian'
  }
  $ensure_service = $ensure ? {
    'present' => 'running',
    'absent'  => 'stopped',
  }
  service {'ucrandom':
    ensure   => $ensure_service,
    provider => $_provider,
  }
}
