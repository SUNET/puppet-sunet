# Install OpenSSH and configure it to a secure baseline.
class sunet::security::configure_sshd() {
  package { 'openssh-server':
    ensure => 'installed'
  } ->

  service { 'ssh':
    ensure    => 'running',
  }

  include augeas
  augeas { "sshd_config":
    context => "/files/etc/ssh/sshd_config",
    changes => [
                "set PasswordAuthentication no",
                "set X11Forwarding no",
                "set LogLevel VERBOSE",  # log pubkey used for root login
                ],
    notify  => Service['ssh'],
  } ->

  sunet::snippets::file_line { 'no_sftp_subsystem':
    ensure   => 'comment',
    filename => '/etc/ssh/sshd_config',
    line     => 'Subsystem sftp',
    notify   => Service['ssh'],
  }
}

# Make sure automatic security upgrades are activated
class sunet::security::unattended_upgrades() {
  file { '/etc/dpkg/unattended-upgrades.debconf':
    ensure  => present,
    content => template('eduid/common/unattended-upgrades.debconf.erb'),
    } ->
  exec { 'enable_unattended_upgrades':
    command => 'debconf-set-selections /etc/dpkg/unattended-upgrades.debconf && dpkg-reconfigure -fdebconf unattended-upgrades',
    unless  => 'debconf-show unattended-upgrades | grep -q "unattended-upgrades/enable_auto_updates: true$"',
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }
}
