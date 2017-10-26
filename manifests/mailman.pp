class sunet::mailman {
  $domain = $::domain
  $mail_hostname = lists2
  $initial_list_pwd = safe_hiera('mailman_list_password',[])
  $sitepass_pwd = safe_hiera('mailman_admin_password',[])
  $list_creator_pwd = safe_hiera('mailman_list_creator',[])
  
  ensure_packages(['mailman','apache2'], {'ensure' => 'present'})

  service { 'postfix':
    ensure  => running,
    enable  => true,
  }

  service { 'mailman':
    require   => Exec['create_initial_list'],
    enable  => true,
    ensure  => running,
  }
 
  service { 'apache2':
    ensure  => running,
    enable  => true,
  }

  file { '/etc/postfix/main.cf':
    ensure  => file,
    mode    => '644',
    content => template('sunet/mailman/main.cf.erb'),
    require => Package['postfix'],
  }

  file { '/etc/postfix/transport':
    ensure  => file,
    mode    => '644',
    content => template('sunet/mailman/transport.erb'),
  }
  
  exec { "build_transport_map":
     command => "postmap -v /etc/postfix/transport",
     subscribe => File['/etc/postfix/transport'], 
     refreshonly => true,
     notify => Service['postfix'],
  }
  
  exec { "create_initial_list":
    command => "newlist mailman mailman@$mail_hostname.$domain $initial_list_pwd",
    creates => "/var/lib/mailman/lists/mailman/config.pck",
  }

  exec { "create_site_pw":
    command => "mmsitepass $sitepass_pwd",
  }

  exec { "create_list_creator_pw":
    command => "mmsitepass -c $list_creator_pwd",
  }

  file { '/etc/mailman/mm_cfg.py':
    content => template('sunet/mailman/mm_cfg.py.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '644',
    notify  => Service['mailman'],
  }

  ufw::allow {"allow_smtp": ip => "any", port => "25", proto => "tcp" } 


  file { '/etc/apache2/sites-available/mailman-ssl.conf':
    ensure  => file,
    mode    => '644',
    content => template('sunet/mailman/mailman-ssl.conf.erb'),
    notify => Service['apache2'],
  }

  file { '/etc/apache2/sites-enabled/mailman-ssl.conf':
    ensure  => link,
    target => '/etc/apache2/sites-available/mailman-ssl.conf',
    require => File['/etc/apache2/sites-available/mailman-ssl.conf'],
  }

  augeas{ "add_https_redirect":
    context => "/files/etc/apache2/sites-available/000-default.conf/VirtualHost",
    changes => [
       "set directive[. = 'Redirect'] 'Redirect'",
       "set directive[. = 'Redirect']/arg[1] 'permanent'",
       "set directive[. = 'Redirect']/arg[2] '/'",
       "set directive[. = 'Redirect']/arg[3] 'https://$mail_hostname.sunet.se/'",
    ],
    notify => Service['apache2'],
  }

  exec { "enables_ssl_cgi_apache":
    command => "a2enmod ssl && a2enmod cgid",
    subscribe => File['/etc/apache2/sites-available/mailman-ssl.conf'],
    refreshonly => true,
  }

  exec { "check_file_permissions":
    command => "check_perms -f",
  }

}
