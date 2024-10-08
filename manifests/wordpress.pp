# a basic wp setup using docker

define sunet::wordpress (
  $db_host           = undef,
  $sp_hostname       = undef,
  $sp_contact        = undef,
  $wordpress_image   = 'wordpress',
  $wordpress_version = '4.1.1',
  # Here one can specify e.g. ${::ipaddress_eth1}:8080:80
  $wordpress_ports   = '8080:80',
  $mysql_version     = '5.7',
  $mysql_user        = undef,
  $mysql_db_name     = undef,
  $mysql_dump        = false
)
{
  include augeas
  $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '_', 'G')
  $db_hostname = $db_host ? {
      undef   => "${safe_name}_mysql.docker",
      default => $db_host
  }
  $db_user = $mysql_user ? {
      undef   => $name,
      default => $mysql_user
  }
  $db_name = $mysql_db_name ? {
      undef   => $name,
      default => $mysql_db_name
  }
  $pwd = lookup("${name}_db_password", undef, undef, undef)
  ensure_resource('file',["/data/${name}","/data/${name}/html","/data/${name}/credentials"], {ensure => directory})
  sunet::docker_run { "${name}_wordpress":
      image    => $wordpress_image,
      imagetag => $wordpress_version,
      volumes  => ["/data/${name}/html:/var/www/html","/data/${name}/credentials:/etc/shibboleth/credentials"],
      ports    => [$wordpress_ports],
      depends  => [$db_hostname],
      env      => [ "SERVICE_NAME=${name}",
                      "SP_HOSTNAME=${sp_hostname}",
                      "SP_CONTACT=${sp_contact}",
                      "WORDPRESS_DB_HOST=${db_hostname}",
                      "WORDPRESS_DB_USER=${db_user}",
                      "WORDPRESS_DB_NAME=${db_name}",
                      "WORDPRESS_DB_PASSWORD=${pwd}" ]
  }

  file { '/usr/local/bin/get_container_ip':
      ensure  => file,
      mode    => '0750',
      owner   => 'root',
      group   => 'root',
      path    => '/usr/local/bin/get_container_ip',
      content => template('sunet/dockerhost/get_container_ip.erb'),
  }
  if (!$db_host) {
      file {"/data/${name}/db": ensure => directory }
      group { 'mysql': ensure => 'present', system => true }
      -> user { 'mysql': ensure => 'present', groups => 'mysql', system => true }
      -> sunet::docker_run { "${name}_mysql":
          image    => 'mysql',
          imagetag => $mysql_version,
          volumes  => ["/data/${name}/db:/var/lib/mysql"],
          env      => ["MYSQL_USER=${db_user}",
                          "MYSQL_PASSWORD=${pwd}",
                          "MYSQL_ROOT_PASSWORD=${pwd}",
                          "MYSQL_DATABASE=${db_name}"],
      }
      package {['mysql-client','mysql-client-5.5','automysqlbackup']: ensure => latest }
      -> augeas { 'automysqlbackup_settings':
        incl    => '/etc/default/automysqlbackup',
        lens    => 'Shellvars.lns',
        changes => [
            "set USERNAME ${db_user}",
            "set PASSWORD ${pwd}",
            "set DBHOST '`/usr/local/bin/get_container_ip ${name}_mysql`'",
            "set DBNAMES ${db_name}"
        ]
      }
    if ($mysql_dump) {
      file { "/data/${name}/dump":
        ensure => directory
      }
      -> cron { "${name}_mysql_dump":
        command => "mysqldump -h $(/usr/local/bin/get_container_ip ${name}_mysql) -u ${db_user} -p${pwd} ${db_name} > /data/${name}/dump/${db_name}.sql.new && test -s /data/${name}/dump/${db_name}.sql.new && mv /data/${name}/dump/${db_name}.sql.new /data/${name}/dump/${db_name}.sql",
        user    => 'root',
        minute  => '*/5'
      }
    }
    file { "/data/${name}/scripts":
      ensure => directory
    }
    -> file { "/data/${name}/scripts/load_${name}.sh":
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => inline_template("#!/bin/bash\nsed 's/${1}/${2}/g' | mysql -h $(/usr/local/bin/get_container_ip ${name}_mysql) -u ${db_user} -p${pwd} ${db_name}")
    }
  }
}
