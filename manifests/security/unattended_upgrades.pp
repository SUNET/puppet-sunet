# Make sure automatic security upgrades are activated
class sunet::security::unattended_upgrades(
  $use_template = false,
) {
  file { '/etc/dpkg/unattended-upgrades.debconf':
    ensure  => present,
    content => template('sunet/security/unattended-upgrades.debconf.erb'),
    } ->
  exec { 'enable_unattended_upgrades':
    command => 'debconf-set-selections /etc/dpkg/unattended-upgrades.debconf && dpkg-reconfigure -fdebconf unattended-upgrades',
    unless  => 'debconf-show unattended-upgrades | grep -q "unattended-upgrades/enable_auto_updates: true$"',
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }
  if $use_template {
    if $::operatingsystem == 'Ubuntu' {
      case $::operatingsystemrelease {
        '14.04':  { file { '/etc/apt/apt.conf.d/50unattended-upgrades':
                    ensure  => present,
                    content => template('sunet/security/50unattended-upgrades.ubuntu_14.04.erb')}
                  }
        '16.04':  { file { '/etc/apt/apt.conf.d/50unattended-upgrades':
                    ensure  => present,
                    content => template('sunet/security/50unattended-upgrades.ubuntu_16.04.erb')}
                  }
        '18.04':  { file { '/etc/apt/apt.conf.d/50unattended-upgrades':
                    ensure  => present,
                    content => template('sunet/security/50unattended-upgrades.ubuntu_18.04.erb')}
                  }
        default:  { file { '/etc/apt/apt.conf.d/50unattended-upgrades':
                    ensure  => present,
                    content => template('sunet/security/50unattended-upgrades.ubuntu_default.erb')}
                  }
      }
    } elsif $::operatingsystem == 'Debian' {
        file { '/etc/apt/apt.conf.d/50unattended-upgrades' :
          ensure  => present,
          content => template('sunet/security/50unattended-upgrades.debian_default.erb'),
        }
    } else {
        warning('Unsupported OS for class sunet::security::unattended_upgrades')
    }
  }
}
