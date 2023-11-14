# Install OpenSSH and configure it to a secure baseline.
# @param configure_sftp  Whether to disable the SFTP subsystem or just leave it alone.
# @param port            The port to configure sshd to listen on. If undef, we leave it to sshd to decide.
class sunet::security::configure_sshd (
  Boolean $configure_sftp = true,
  Optional[Integer] $port = lookup('sunet_ssh_daemon_port', Optional[integer], undef,  undef),
) {
  ensure_resource('package', 'openssh-server', {
      ensure => 'installed'
  })

  ensure_resource('service', 'ssh', {
      ensure => 'running',
      enable => true,
  })

  if $::facts['operatingsystemrelease'] != '12.04' {
    # Generate an ed25519 ssh host key. Ubuntu 12.04 does not support that, but hopefully
    # everything running !ubuntu does so we only exclude 12.04.
    exec { 'ed25519-ssh-host-key':
      command => 'ssh-keygen -t ed25519 -N "" -f /etc/ssh/ssh_host_ed25519_key',
      onlyif  => 'test ! -s /etc/ssh/ssh_host_ed25519_key.pub -o ! -s /etc/ssh/ssh_host_ed25519_key'
    }
    $set_hostkey = [
      'set HostKey[1] /etc/ssh/ssh_host_ed25519_key',
      #'set HostKey[2] /etc/ssh/ssh_host_rsa_key',
    ]
  } else {
    $set_hostkey = ['set HostKey[1] /etc/ssh/ssh_host_rsa_key']
  }

  if $::facts['has_ssh_host_ed25519_cert'] == 'yes' {
    $set_hostcert = ['set HostCertificate[1] /etc/ssh/ssh_host_ed25519_key-cert']
  } else {
    $set_hostcert = ['rm HostCertificate']
  }

  if $port != undef {
    $set_port = "set Port ${port}"
  } else {
    $set_port = undef
  }

  augeas { 'sshd_config':
    context => '/files/etc/ssh/sshd_config',
    changes => flatten([
        'set PasswordAuthentication no',
        'set X11Forwarding no',
        'set AllowAgentForwarding no',
        'set LogLevel VERBOSE',  # log pubkey used for root login
        'rm HostKey',
        $set_hostkey,
        $set_hostcert,
        $set_port,
    ]).filter |$this| { $this != undef },
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
