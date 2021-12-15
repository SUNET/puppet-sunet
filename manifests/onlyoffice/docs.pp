# OnlyOffice document server
define sunet::onlyoffice::docs(
  String            $amqp_server      = 'localhost',
  String            $amqp_type        = 'rabbitmq',
  String            $amqp_user        = 'sunet',
  String            $basedir          = "/opt/onlyoffice/docs/${name}",
  String            $contact_mail     = 'noc@sunet.se',
  String            $db_host          = undef,
  String            $db_name          = 'onlyoffice',
  String            $db_type          = 'mariadb',
  String            $db_user          = 'onlyoffice',
  String            $docker_image     = 'onlyoffice/documentserver',
  String            $docker_tag       = 'latest',
  Array[String]     $dns              = [],
  Optional[String]  $external_network = undef,
  String            $hostname         = $::fqdn,
  Enum['yes', 'no'] $letsencrypt      = 'no',
  Integer           $port             = 80,
  String            $redis_host       = undef,
  Integer           $redis_port       = 6379,
  Integer           $tls_port         = 443,
  ) {

  sunet::misc::ufw_allow { 'web_ports':
    from => 'any',
    port => [$port, $tls_port, 8000],
  }
  sunet::system_user {'ds': username => 'ds', group => 'ds' }
  $amqp_secret = safe_hiera('amqp_password',undef)
  $amqp_env = $amqp_secret ? {
    undef   => [],
    default => ["AMQP_TYPE=${amqp_type}","AMQP_URI=amqp://${amqp_user}:${amqp_secret}@${amqp_server}:5672"]
  }

  $db_pwd = safe_hiera('mysql_user_password',undef)

  $db_env = ["DB_HOST=${db_host}","DB_NAME=${db_name}","DB_USER=${db_user}","DB_TYPE=${db_type}"]
  $db_pwd_env = $db_pwd ? {
    undef   => [],
    default => ["DB_PWD=${db_pwd}"]
  }

  $jwt_secret = safe_hiera('document_jwt_key',undef)
  $jwt_env = $jwt_secret ? {
    undef   => [],
    default => ['JWT_ENABLED=yes',"JWT_SECRET=${jwt_secret}"]
  }

  $le_env = $letsencrypt ? {
    'no'    => [],
    default => ["LETS_ENCRYPT_DOMAIN=${hostname}","LETS_ENCRYPT_MAIL=${contact_mail}"]
  }

  $redis_secret = safe_hiera('redis_host_password',undef)
  $redis_env = $redis_secret ? {
    undef   => [],
    default => ["REDIS_SERVER_HOST=${redis_host}","REDIS_SERVER_PASSWORD=${redis_secret}","REDIS_SERVER_PORT=${redis_port}"]
  }
  $ds_environment = flatten([$amqp_env,$db_env,$db_pwd_env,$jwt_env,$le_env,$redis_env])
  exec {"${name}_mkdir_basedir":
    command => "mkdir -p ${basedir}",
    unless  => "/usr/bin/test -d ${basedir}"
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
  -> file { "${basedir}/run-document-server.sh":
    ensure  => file,
    mode    => '0755',
    content => template('sunet/onlyoffice/run-document-server.sh.erb'),
  }
  -> file {[$basedir,"${basedir}/logs","${basedir}/data","${basedir}/data/certs",
  "${basedir}/lib"]: ensure => directory }
}
