class sunet::ipam::proxy_auth {

  include sunet::ipam::main

  # Install dependencies for mod_auth_mellon which is an authentication module for Apache.
  package { ['pkg-config', 'liblasso3', 'libapache2-mod-auth-mellon']:
    ensure => installed,
  }

  # The file contains configurations for proxy authentication via nipap web GUI.
  file { '/usr/lib/python2.7/dist-packages/nipapwww/controllers/proxy_auth.py':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/ipam/proxy_auth.erb'),
  }
  # Adds the button in login page.
  -> file_line { 'add_button':
      ensure => 'present',
      line   => '          <dd>{{ h.submit(\'send\', \'Log in\', class=\'button button_red\') }} <a href="{{ url(controller=\'proxy_auth\', action=\'login\') }}" class="button button_blue">NORDUnet SSO</a></dd>',
      path   => '/usr/lib/python2.7/dist-packages/nipapwww/templates/login.html',
      match  => '<dd>{{ h.submit',
      notify  => Service['nipapd'],
      }
  -> file { '/opt/ndn-metadata':
      ensure  => directory,
      }
  # Create private key and certificate for Apache to authenticate SP
  -> sunet::snippets::keygen {"sp_authentication":
      key_file  => '/opt/ndn-metadata/sp.key',
      cert_file => '/opt/ndn-metadata/sp.crt',
      }
  # A script to bring and update metadata file from idp.nordu.net
  -> file { '/opt/ndn-metadata/md-update.sh':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/ipam/md-update.sh.erb'),
      }
  # Run above script everyday to keep the metadata up-to-date.
  -> sunet::scriptherder::cronjob { 'update_ndn_metadata':
      cmd           => '/opt/ndn-metadata/md-update.sh -q -o /opt/ndn-metadata/idp.nordu.net.xml https://idp.nordu.net/idp/shibboleth',
      minute        => '30',
      hour          => '6',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
      }
}