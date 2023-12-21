class sunet::vc::sealer(
  String $interface               ="ens3",
  Boolean $production             =false,
  String $pkcs11_module           = '/usr/lib/softhsm/libsofthsm2.so',
  String $pkcs11_label,
  String $pkcs11_cert_label,
  String $pkcs11_key_label,
  String $pkcs11_pin              = lookup('pkcs11_pin'), 
  Integer $pkcs11_slot            = 0,
  String $host_environments          = "softhsm2",
  String $pdfsigner_version              = "latest",
  String $pdfsigner_flavor               = "ca-softhsm2",
  String $pdfsigner_addr,
  String $safenetauthenticationclient_core_url = "https://www.digicert.com/StaticFiles/SAC_10_8_28_GA_Build.zip",
) {

  sunet::ssh_keys { 'vcops':
    config => lookup('vcops_ssh_config', undef, undef, {}),
  }

  if $host_environments == "softhsm2" {
    sunet::vc::host_environments::softhsm2 { "softhsm2":
      pkcs11_module     => $pkcs11_module,
      pkcs11_label      => $pkcs11_label,
      pkcs11_cert_label => $pkcs11_cert_label,
      pkcs11_key_label  => $pkcs11_key_label,
      pkcs11_pin        =>$pkcs11_pin,
      pkcs11_slot       => $pkcs11_slot,
    }
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
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    content => template("sunet/vc/sealer/config.yaml.erb")
   }

  file { '/opt/vc/haproxy.cfg':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content =>  template("sunet/vc/sealer/haproxy.cfg.erb")
  }

  file { '/opt/vc/Makefile':
    ensure => file,
    mode => '0744',
    owner => 'root',
    group => 'root',
    content => template("sunet/vc/sealer/Makefile.erb")
  }

  file { '/opt/vc/certs':
    ensure  => directory,
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
  }

  sunet::remote_file { "/opt/vc/libssl1.1_1.1.0g-2ubuntu4_amd64.deb":
      remote_location => "http://archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.0g-2ubuntu4_amd64.deb",
      mode            => "0600",
    } ->
    exec {"Install libssl1.1":
        command => "dpkg -i /opt/vc/libssl1.1_1.1.0g-2ubuntu4_amd64.deb"
    }

  sunet::remote_file { "/tmp/safenetauthenticationclient-core.zip":
      remote_location => $safenetauthenticationclient_core_url,
      mode            => "0600",
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
  sunet::docker_compose { 'vc_sealer':
    content          => template('sunet/vc/sealer/docker-compose.yml.erb'),
    service_name     => 'vc',
    compose_dir      => '/opt',
    compose_filename => 'docker-compose.yml',
    description      => 'VC-sealer service',
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
  } else {
    sunet::misc::ufw_allow { 'web_ports':
      from => 'any',
      port => ['80', '443']
    }
  }
}
