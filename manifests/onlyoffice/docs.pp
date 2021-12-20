# OnlyOffice document server
define sunet::onlyoffice::docs(
  String           $basedir      = "/opt/onlyoffice/docs/${name}",
  String           $contact_mail = 'noc@sunet.se',
  String           $db_host      = undef,
  String           $db_name      = 'onlyoffice',
  String           $db_type      = 'mysql',
  String           $db_user      = 'onlyoffice',
  String           $docker_image = 'onlyoffice/documentserver',
  String           $docker_tag   = 'latest',
  Array[String]    $dns          = [],
  String           $hostname     = $::fqdn,
  Enum['yes','no'] $letsencrypt  = 'no',
  Integer          $port         = 8080,
  Integer          $tls_port     = 8443,
  ) {

  sunet::system_user {'ds': username => 'ds',group => 'ds' }

  $db_pwd = safe_hiera('document_db_password',undef)

  $db_env = ["DB_HOST=${db_host}","DB_NAME=${db_name}","DB_USER=${db_user}","DB_TYPE=${db_type}"]
  $db_pwd_env = $db_pwd ? {
    undef   => [],
    default => ["DB_PWD=${db_pwd}"]
  }

  $jwt_secret = safe_hiera('document_jwt_key',undef)
  $jwt_env = $jwt_secret ? {
    undef   => [],
    default => ['JWT_ENABLED=true',"JWT_SECRET=${jwt_secret}"]
  }

  $le_env = $letsencrypt ? {
    'no'    => [],
    default => ["LETS_ENCRYPT_DOMAIN=${hostname}","LETS_ENCRYPT_MAIL=${contact_mail}"]
  }

  $ds_environment = flatten([$db_env,$db_pwd_env,$jwt_env,$le_env])
  exec {"${name}_mkdir_basedir":
    command => "mkdir -p ${basedir}/data/certs",
    unless  => "/usr/bin/test -d ${basedir}/data/certs"
  }
  -> exec {"${name}_create_key":
    command => "/usr/bin/openssl genrsa -out ${basedir}/data/certs/onlyoffice.key 2048",
    unless  => "/usr/bin/test -s ${basedir}/data/certs/onlyoffice.key"
  }
  -> exec {"${name}_create_csr":
    command => "/usr/bin/openssl req -new -key ${basedir}/data/certs/onlyoffice.key -out ${basedir}/data/certs/onlyoffice.csr -subj '/C=SE/ST=Stockholm/L=Stockholm/O=SUNET/OU=Drive Team/CN=${hostname}'",
    unless  => "/usr/bin/test -s ${basedir}/data/certs/onlyoffice.csr"
  }
  -> exec {"${name}_create_crt":
    command => "/usr/bin/openssl x509 -req -days 3650 -signkey ${basedir}/data/certs/onlyoffice.key -in ${basedir}/data/certs/onlyoffice.csr -out ${basedir}/data/certs/onlyoffice.crt",
    unless  => "/usr/bin/test -s ${basedir}/data/certs/onlyoffice.crt"
  }
  -> exec {"${name}_create_dhparam":
    command => "/usr/bin/openssl dhparam -out ${basedir}/data/certs/dhparam.pem 2048",
    unless  => "/usr/bin/test -s ${basedir}/data/certs/dhparam.pem"
  }
  -> sunet::docker_compose { $name:
    content          => template('sunet/onlyoffice/docker-compose.yml.erb'),
    service_name     => 'onlyoffice',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'OnlyOffice Document Server',
  }
  -> file {[$basedir,"${basedir}/logs","${basedir}/data","${basedir}/data/certs","${basedir}/lib"]: ensure => directory }
}
