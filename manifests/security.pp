# Install OpenSSH and configure it to a secure baseline.
class sunet::security::configure_sshd(
    $configure_sftp = true,
) {
  ensure_resource('package', 'openssh-server', {
    ensure => 'installed'
  })

  ensure_resource('service', 'ssh', {
    ensure    => 'running',
    enable    => true,
  })

  if $::operatingsystemrelease != '12.04' {
    # Generate an ed25519 ssh host key. Ubuntu 12.04 does not support that, but hopefully
    # everything running !ubuntu does so we only exclude 12.04.
    exec { "ed25519-ssh-host-key":
      command => 'ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key',
      onlyif  => 'test ! -s /etc/ssh/ssh_host_ed25519_key.pub -o ! -s /etc/ssh/ssh_host_ed25519_key'
    }
    $set_hostkey = ['set HostKey[1] /etc/ssh/ssh_host_ed25519_key',
                    'set HostKey[2] /etc/ssh/ssh_host_rsa_key',
                    ]
  } else {
    $set_hostkey = ['set HostKey[1] /etc/ssh/ssh_host_rsa_key']
  }

  include augeas
  augeas { "sshd_config":
    context => "/files/etc/ssh/sshd_config",
    changes => flatten([
                        "set PasswordAuthentication no",
                        "set X11Forwarding no",
                        "set LogLevel VERBOSE",  # log pubkey used for root login
                        "rm HostKey",
                        $set_hostkey,
                        ]),
    notify  => Service['ssh'],
    require => Package['openssh-server'],
  }
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
