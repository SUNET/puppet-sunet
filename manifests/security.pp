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
                    #'set HostKey[2] /etc/ssh/ssh_host_rsa_key',
                    ]
  } else {
    $set_hostkey = ['set HostKey[1] /etc/ssh/ssh_host_rsa_key']
  }
  
  if $::has_ssh_host_ed25519_cert == 'yes' {
     $set_hostcert = ["set HostCertificate[1] /etc/ssh/ssh_host_ed25519_key-cert"] 
  } else {
     $set_hostcert = ["rm HostCertificate"]
  }

  include augeas
  augeas { "sshd_config":
    context => "/files/etc/ssh/sshd_config",
    changes => flatten([
                        "set PasswordAuthentication no",
                        "set X11Forwarding no",
                        "set AllowAgentForwarding no",
                        "set LogLevel VERBOSE",  # log pubkey used for root login
                        "rm HostKey",
                        $set_hostkey,
                        $set_hostcert,
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

# disable ALL local users
class sunet::security::disable_all_local_users() {
  exec {'disable_all_local_users_exec':
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
    command => 'cat /etc/passwd | awk -F : \'{print $1}\' | xargs --no-run-if-empty --max-args=1 usermod --lock',
    onlyif  => 'cat /etc/shadow | awk -F : \'{print $2}\' | grep -v ^!',
    before  => Package['openssh-server'],
  }
}

# Since Apparmor is not enabled by default on Debian 9 we need to
# change the boot parameters for the kernel to turn it on.
# Debian 10 will, according to the current information, have
# Apparmor enabled by default so this might not be needed in the future.
# apparmor-utils is installed so we can test and debug profiles.
class sunet::security::apparmor() {
    package {'apparmor-utils': ensure => latest }
    if $::operatingsystem == 'Debian' {
        case $::operatingsystemmajrelease {
            '9':  { exec { 'enable_apparmor_on_Debian_9':
                    command => 'bash -c \'source /etc/default/grub && sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT}\"/GRUB_CMDLINE_LINUX_DEFAULT=\"${GRUB_CMDLINE_LINUX_DEFAULT} apparmor=1 security=apparmor\"/g" /etc/default/grub && update-grub\'',
                    unless => 'grep -q "apparmor" /etc/default/grub', }
                  }
        }
    }
}
