class sunet::dovecot
{
  package {['dovecot-imapd', 'dovecot-lmtpd', 'dovecot-sieve']: }
  -> service { 'dovecot':
    ensure => 'running'
  }
  sunet::misc::ufw_allow { 'imaps':
    from => 'any',
    port => '993',
  }
}
