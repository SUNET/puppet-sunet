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

    concat { '/etc/apt/apt.conf.d/51unattended-upgrades-origins':
      owner          => 'root',
      ensure_newline => true,
      group          => 'root',
      mode           => '0644'
    }

    concat::fragment { 'origins_header':
      target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
      content => template('sunet/security/51unattended-upgrades-origins-header.erb'),
      order   => '01'
    }
    concat::fragment { 'origins_footer':
      target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
      content => template('sunet/security/51unattended-upgrades-origins-header.erb'),
      order   => '9001'
    }

    if $facts['os']['name'] == 'Ubuntu' {
      file { '/etc/apt/apt.conf.d/50unattended-upgrades':
        content => template('sunet/security/50unattended-upgrades.ubuntu_default.erb')
      }

      concat::fragment { 'origin_ubuntu':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Ubuntu,codename=${distro_codename}";' # lint:ignore:single_quote_string_with_variables
      }
      concat::fragment { 'origin_ubuntu_security':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Ubuntu,codename=${distro_codename}-security";' # lint:ignore:single_quote_string_with_variables
      }
      concat::fragment { 'origin_ubuntu_esm_apps':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=UbuntuESMApps,codename=${distro_codename}-apps-security";' # lint:ignore:single_quote_string_with_variables: lint:ignore:140chars
      }
      concat::fragment { 'origin_ubuntu_esm':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=UbuntuESM,codename=${distro_codename}-infra-security";' # lint:ignore:single_quote_string_with_variables
      }
      concat::fragment { 'origin_ubuntu_updates':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Ubuntu,codename=${distro_codename}-updates";' # lint:ignore:single_quote_string_with_variables
      }
    } elsif $facts['os']['name'] == 'Debian' {
      file { '/etc/apt/apt.conf.d/50unattended-upgrades' :
        content => template('sunet/security/50unattended-upgrades.debian_default.erb'),
      }

      concat::fragment { 'origin_debian_updates':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Debian,codename=${distro_codename}-updates";' # lint:ignore:single_quote_string_with_variables
      }
      concat::fragment { 'origin_debian':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Debian,codename=${distro_codename},label=Debian";' # lint:ignore:single_quote_string_with_variables
      }
      concat::fragment { 'origin_debian_security':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Debian,codename=${distro_codename},label=Debian-Security";' # lint:ignore:single_quote_string_with_variables lint:ignore:140chars
      }
      concat::fragment { 'origin_debian_security_security':
        target  => '/etc/apt/apt.conf.d/51unattended-upgrades-origins',
        content => '"origin=Debian,codename=${distro_codename}-security,label=Debian-Security";' # lint:ignore:single_quote_string_with_variables lint:ignore:140chars
      }

    } else {
      warning('Unsupported OS for class sunet::security::unattended_upgrades')
    }
  }
}
