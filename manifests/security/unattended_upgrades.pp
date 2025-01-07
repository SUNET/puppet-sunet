# Make sure automatic security upgrades are activated
# @param use_template  Create /etc/apt/apt.conf.d/50unattended-upgrades using a template
class sunet::security::unattended_upgrades (
  Boolean $use_template = false,
) {
  file { '/etc/dpkg/unattended-upgrades.debconf':
    content => template('sunet/security/unattended-upgrades.debconf.erb'),
  }
  exec { 'enable_unattended_upgrades':
    command => 'debconf-set-selections /etc/dpkg/unattended-upgrades.debconf && dpkg-reconfigure -fdebconf unattended-upgrades',
    unless  => 'debconf-show unattended-upgrades | grep -q "unattended-upgrades/enable_auto_updates: true$"',
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin',],
  }
  if $use_template {
    if $facts['os']['name'] == 'Ubuntu' {
      file { '/etc/apt/apt.conf.d/50unattended-upgrades':
        content => template('sunet/security/50unattended-upgrades.ubuntu_default.erb') }
      }
    } elsif $facts['os']['name'] == 'Debian' {
      file { '/etc/apt/apt.conf.d/50unattended-upgrades' :
        content => template('sunet/security/50unattended-upgrades.debian_default.erb'),
      }
    } else {
      warning('Unsupported OS for class sunet::security::unattended_upgrades')
    }
  }
}
