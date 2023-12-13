class sunet::vc::standalone(
  String $vc_version              ="latest",
  String $mongodb_version         ="4.0.10",
  String $interface               ="ens3",
  Boolean $production             =false,
  String $pkcs11_sign_api_token   = lookup('pkcs11_sign_api_token'), 
  String $pkcs11_token            = lookup('pkcs11_token'),
  String $pkcs11_pin              = lookup('pkcs11_pin'), 
  String $pkcs11_module           = '/usr/lib/softhsm/libsofthsm2.so',
  String $postgres_host           = 'ca_postgres',
  String $postgres_database       = 'pkcs11_testdb1',
  String $postgres_user           = 'pkcs11_testuser1',
  String $postgres_password       = lookup('postgres_password'), 
  String $postgres_port           = '5432',
  String $postgres_timeout        = '5',
  String $postgres_image		      = 'postgres',
  String $postgres_version		    = '15.2-bullseye@sha256:f1f635486b8673d041e2b180a029b712a37ac42ca5479ea13029b53988ed164c',
  String $ca_acme_root            = '/acme',
  String $ca_token,
  String $ca_url,
  String $ca_version              = "latest",
  String $ca_flavor               = "ca-softhsm2",
  String $ca_reason               = "Ladok",
  String $ca_location             = "Stockholm",
  String $ca_name                 = "Sunet",
  String $ca_contact_info         = "noc@sunet.se",
  String $safenetauthenticationclient_core_url = "https://www.digicert.com/StaticFiles/SAC_10_8_28_GA_Build.zip",
  String $mongo_user              = lookup('mongo_user'),
  String $mongo_pw                = lookup('mongo_pw')
  #hash with basic_auth key/value
) {

  sunet::ssh_keys { 'vcops':
    config => lookup('vcops_ssh_config', undef, undef, {}),
  }

 package { 'make': ensure => 'installed' }

  sunet::misc::system_user { 'sunet':
    username   => 'sunet',
    group      => 'sunet',
    shell      => '/bin/false',
    managehome => false
  }

  file { '/var/log/sunet':
    ensure => directory,
    mode    => '0770',
    group   => 'sunet',
    require =>  [ Group['sunet'] ],
  }

  file { '/opt/vc/config.yaml':
    ensure => file,
    mode   => '0600',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/standalone/config.yaml.erb")
   }

  file { '/opt/vc/haproxy.cfg':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content =>  template("sunet/vc/standalone/haproxy.cfg.erb")
  }

  file { '/opt/pkcs11_ca':
    ensure => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  file { '/opt/pkcs11_ca/mk_keys.sh':
    ensure  => file,
    mode    => '0744',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/vc/standalone/mk_keys.sh.erb'),
  }

  file { '/opt/pkcs11_ca/postgres_shell.sh':
    ensure  => file,
    mode    => '0744',
    owner   => 'root',
    group   => 'root',
    content => template('sunet/vc/standalone/postgres_shell.sh.erb'),
  }

  # Setup the pkcs11_ca keys
  exec { 'mk_keys':
    command     => '/usr/bin/bash ./mk_keys.sh',
    cwd         => '/opt/pkcs11_ca',
  }

  file { '/opt/pkcs11_ca/data/hsm_tokens':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => '1500',
  }

  file { '/opt/pkcs11_ca/data/db_data': 
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => '999',
  }

  file { '/opt/vc/Makefile':
    ensure => file,
    mode => '0744',
    owner => 'root',
    group => 'root',
    content => template("sunet/vc/standalone/Makefile.erb")
  }

  file { '/opt/vc/certs':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  sunet::remote_file { "/tmp/safenetauthenticationclient-core.zip":
      remote_location => $safenetauthenticationclient_core_url,
      mode            => "0600",
      unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    } ->
    exec {"Unpack safenetauthenticationclient-core":
        command => "unzip  /tmp/safenetauthenticationclient-core.zip",
        unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    } ->
    exec {"Install safenetauthenticationclient-core":
        command => "apt-get install 'SAC 10.8.28 GA Build/Installation/withoutUI/Ubuntu-2004/safenetauthenticationclient-core_10.8.28_amd64.deb' -y",
        unless  => "test -f /tmp/safenetauthenticationclient-core.zip",
    }

  # Compose
  sunet::docker_compose { 'vc_standalone':
    content          => template('sunet/vc/standalone/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-standalone service',
  }

  if $::facts['sunet_nftables_enabled'] == 'yes' {
    sunet::nftables::docker_expose { 'web_http_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 80,
    }
    sunet::nftables::docker_expose { 'web_https_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 443,
    }
    sunet::nftables::docker_expose { 'jaeger_ui_port' :
      iif           => $interface,
      allow_clients => 'any',
      port          => 16686,
    }
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
