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
    line     => 'Subsystem sftp /usr/lib/openssh/sftp-server',
    notify   => Service['ssh'],
  }
}
