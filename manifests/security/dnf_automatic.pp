# Install security updates using the EL systemd timer.
class sunet::security::dnf_automatic {
  package { 'dnf-automatic': ensure => installed }
  augeas { 'dnf automatic security updates':
    lens    => 'Puppet.lns',
    incl    => '/etc/dnf/automatic.conf',
    changes => 'set commands/upgrade_type security',
    require => Package['dnf-automatic'],
    before  => Service['dnf-automatic-install.timer'],
  }
  service { 'dnf-automatic-install.timer':
    ensure  => running,
    enable  => true,
    require => Package['dnf-automatic'],
  }
}
