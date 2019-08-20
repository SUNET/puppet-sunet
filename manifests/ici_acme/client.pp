# Acquire a certificate from an ICI ACME server
class sunet::ici_acme::client(
  String $ca_url = 'http://ca-test-1.sunet.se/',
) {
  package { 'python3-josepy':
    ensure => 'installed',
  }

  sunet::misc::create_dir { '/etc/ici_acme/dehydrated': owner => 'root', group => 'root', mode => '0700' }

  file {
    '/etc/ici_acme/dehydrated/config':
      ensure  => file,
      mode    => '0600',
      content => template('sunet/ici_acme/dehydrated_config.erb'),
      ;
    '/usr/local/sbin/ici_acme_client':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/ici_acme/ici_acme_client.erb'),
      ;
    '/usr/local/sbin/ici-acme-pre-auth.py':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/ici_acme/ici-acme-pre-auth.py.erb'),
      ;
    '/usr/local/sbin/dehydrated':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/ici_acme/sunet_patched_dehydrated.erb'),
      ;
  }

  sunet::scriptherder::cronjob { 'ici_acme_client':
    cmd           => '/usr/local/sbin/ici_acme_client --random-sleep',
    special       => 'daily',
    ok_criteria   => ['exit_status=0', 'max_age=25h'],
    warn_criteria => ['exit_status=0', 'max_age=49h'],
  }

  sunet::snippets::reinstall::keep { '/etc/ici_acme/': }
}
