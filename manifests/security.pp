# Install OpenSSH and configure it to a secure baseline.
class sunet::security::configure_sshd(
    $configure_sftp = true,
) {
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
    require => Package['openssh-server'],
  } ->
  if $configure_sftp {
    sunet::snippets::file_line { 'no_sftp_subsystem':
      ensure   => 'comment',
      filename => '/etc/ssh/sshd_config',
      line     => 'Subsystem sftp',
      notify   => Service['ssh'],
    }
  }
}

# Make sure automatic security upgrades are activated
class sunet::security::unattended_upgrades() {
  file { '/etc/dpkg/unattended-upgrades.debconf':
    ensure  => present,
    content => template('sunet/security/unattended-upgrades.debconf.erb'),
    } ->
  exec { 'enable_unattended_upgrades':
    command => 'debconf-set-selections /etc/dpkg/unattended-upgrades.debconf && dpkg-reconfigure -fdebconf unattended-upgrades',
    unless  => 'debconf-show unattended-upgrades | grep -q "unattended-upgrades/enable_auto_updates: true$"',
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }
}

# disable ALL local users
class sunet::security::disable_all_local_users() {
  exec {'disable_all_local_users_exec':
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
    command => 'cat /etc/passwd | awk -F : \'{print $1}\' | xargs --no-run-if-empty --max-args=1 usermod --lock',
    onlyif  => 'cat /etc/shadow | awk -F : \'{print $2}\' | grep -v ^!',
    before  => Package['openssh-server'],
  }
}
