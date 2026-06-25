# app class
class sunet::edusign::app(
  String $version = 'latest',
  String $profile = 'edusign-test',
  Optional[String] $host = undef,
  String $ensure = 'present',
  Variant[String, Boolean] $invites = 'no',
  Array[String] $loadbalancers = []) {
  $_host = $host ? {
    undef    => $facts['networking']['fqdn'],
    default  => $host
  }
  sunet::system_user { 'edusign':
    username => 'edusign',
    group    => 'edusign'
  }
  -> sunet::system_user { '_shibd':
    username => '_shibd',
    group    => '_shibd'
  }
  -> file {['/etc/metadata','/var/log/edusign','/var/log/supervisor','/var/log/nginx','/var/log/shibboleth']: ensure => directory }
  -> file {'/etc/edusign': ensure => directory, mode => '0755', owner => 'edusign', group => 'edusign'}
  -> file {'/etc/edusign/data': ensure => directory, mode => '0755', owner => 'edusign', group => 'edusign'}
  -> file {'/etc/logrotate.d/edusign':
    ensure  => file,
    path    => '/etc/logrotate.d/edusign',
    mode    => '0644',
    content => template('nunoc/edusign/logrotate-edusign.erb')
  }
  sunet::metadata::trust::swamid {'required_title':}

  # SP pre v1.5 vars
  $edusign_idp_entityid = hiera('edusign_idp_entityid', '')
  $edusign_metadata_file = hiera('edusign_metadata_file', '')

  # SP post v1.5 vars for bankid
  $bankid_md_path = hiera('bankid_md_path')
  $bankid_entity_id = hiera('bankid_entity_id')
  $edusign_sp_extra_variables = hiera('edusign_sp_extra_variables', [])

  $env_sp = ['METADATA_FILE=/etc/metadata/swamid-idp-transitive.xml',
            "SP_HOSTNAME=${_host}",
            'BACKEND_HOST=edusign-app.docker',
            'MAX_FILE_SIZE=20M',
            'ACMEPROXY=acme-c.sunet.se',
            'DISCO_URL=https://service.seamlessaccess.org/ds/?trustProfile=edugain',
            "MULTISIGN_BUTTONS=${invites}",
            "BANKID_MD_PATH=${bankid_md_path}",
            "BANKID_ENTITY_ID=${bankid_entity_id}"
            ]

  $env_sp_final = $env_sp + $edusign_sp_extra_variables

  if ($edusign_idp_entityid == '') {
    sunet::docker_run{'edusign-sp':
      ensure   => $ensure,
      image    => 'docker.sunet.se/edusign-sp',
      imagetag => $version,
      hostname => $facts['networking']['fqdn'],
      volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/dehydrated:/etc/dehydrated','/etc/metadata:/etc/metadata:ro',
                    '/etc/edusign:/etc/edusign:ro', '/opt/metadata/trust/swamid/md-signer2.crt:/etc/shibboleth/md-signer2.crt:ro'],
      env      => $env_sp_final,
      depends  => ['edusign-app'],
      ports    => ['443:443','80:80']
    }
  } else {
    sunet::docker_run{'edusign-sp':
      ensure   => $ensure,
      image    => 'docker.sunet.se/edusign-sp',
      imagetag => $version,
      hostname => $facts['networking']['fqdn'],
      volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/dehydrated:/etc/dehydrated','/etc/metadata:/etc/metadata:ro',
                    '/etc/edusign:/etc/edusign:ro', '/var/run/md-signer2.crt:/etc/shibboleth/md-signer2.crt:ro'],
      env      => $env_sp_final,
      depends  => ['edusign-app'],
      ports    => ['443:443','80:80']
    }
  }

  # APP pre 1.5 vars
  $secret_key = hiera('edusign_secret_key')
  $edusign_api_base_url = hiera('edusign_api_base_url','https://api.edusign.sunet.se/v1/')
  $edusign_api_username = hiera('edusign_api_username')
  $edusign_api_username_11 = hiera('edusign_api_username_11')
  $profile_11 = hiera('edusign_geant_profile',$profile)
  $edusign_api_password = hiera('edusign_api_password')
  $edusign_api_password_20= hiera('edusign_api_password_20', 'NULL')
  $edusign_api_password_11 = hiera('edusign_api_password_11', 'NULL')
  $debug = hiera('edusign_app_debug','false')
  $sign_requester_id = hiera('edusign_sign_requester_id', "https://${_host}/shibboleth")
  $scope_whitelist = hiera('edusign_whitelist')
  $edusign_app_polling = hiera('edusign_app_polling', 'inviter')
  $edusign_app_extra_variables = hiera('edusign_app_extra_variables', [])

  # APP post 1.5 vars for bankid
  $edusign_api_profile_bankid = hiera('edusign_api_profile_bankid')
  $edusign_api_username_bankid = hiera('edusign_api_username_bankid')
  $edusign_api_password_bankid = hiera('edusign_api_password_bankid')
  $edusign_api_profile_freja = hiera('edusign_api_profile_freja')
  $edusign_api_username_freja = hiera('edusign_api_username_freja')
  $edusign_api_password_freja = hiera('edusign_api_password_freja')
  $bankid_idp = hiera('bankid_idp')
  $freja_idp = hiera('freja_idp')

  $env_app = [ "SP_HOSTNAME=${_host}",
              "SERVER_NAME=${host}",
              "SECRET_KEY=${secret_key}",
              "EDUSIGN_API_PROFILE_11=${profile_11}",
              "EDUSIGN_API_USERNAME_11=${edusign_api_username_11}",
              "EDUSIGN_API_PASSWORD_11=${edusign_api_password_11}",
              "EDUSIGN_API_PROFILE_20=${profile_11}",
              "EDUSIGN_API_USERNAME_20=${edusign_api_username_11}",
              "EDUSIGN_API_PASSWORD_20=${edusign_api_password_20}",
              "EDUSIGN_API_BASE_URL=${edusign_api_base_url}",
              "EDUSIGN_API_PROFILE=${profile}",
              "EDUSIGN_API_USERNAME=${edusign_api_username}",
              "EDUSIGN_API_PASSWORD=${edusign_api_password}",
              "SIGN_REQUESTER_ID=${sign_requester_id}",
              "SCOPE_WHITELIST=${scope_whitelist}",
              "DEBUG=${debug}",
              'MAIL_SERVER=smtp.sunet.se',
              'MAIL_PORT=25',
              'MAIL_DEBUG=True',
              'MAIL_SUPPRESS_SEND=False',
              'MAIL_USERNAME=',
              'MAIL_PASSWORD=',
              'MAIL_DEFAULT_SENDER=noreply@sunet.se',
              "MULTISIGN_BUTTONS=${invites}",
              "SESSION_COOKIE_NAME=${profile}",
              'LOCAL_STORAGE_BASE_DIR=/etc/edusign/data',
              'SQLITE_MD_DB_PATH=/etc/edusign/data/edusign.db',
              "POLLING=${edusign_app_polling}",
              'USE_BANKID=True',
              "EDUSIGN_API_PROFILE_BANKID=${edusign_api_profile_bankid}",
              "EDUSIGN_API_USERNAME_BANKID=${edusign_api_username_bankid}",
              "EDUSIGN_API_PASSWORD_BANKID=${edusign_api_password_bankid}",
              "EDUSIGN_API_PROFILE_FREJA=${edusign_api_profile_freja}",
              "EDUSIGN_API_USERNAME_FREJA=${edusign_api_username_freja}",
              "EDUSIGN_API_PASSWORD_FREJA=${edusign_api_password_freja}",
              "BANKID_IDP=${bankid_idp}",
              "FREJA_IDP=${freja_idp}"
  ]

  $env_app_final = $env_app + $edusign_app_extra_variables

  sunet::docker_run{'edusign-app':
    ensure   => $ensure,
    image    => 'docker.sunet.se/edusign-app',
    imagetag => $version,
    volumes  => ['/var/log:/var/log','/etc/ssl:/etc/ssl','/etc/localtime:/etc/localtime:ro','/etc/edusign:/etc/edusign'],
    hostname => $facts['networking']['fqdn'],
    env      => $env_app_final
  }

  if $facts['sunet_nftables_opt_in'] == 'yes' or
    ( $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '22.04') >= 0 ) {
    sunet::nftables::docker_expose { 'signapp' :
      allow_clients => $loadbalancers,
      port          => '443',
      iif           => $facts['interface_default'],
    }
  }
}
