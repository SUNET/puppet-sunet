# a basic wp setup using docker

define sunet::wordpress (
$db_host           = undef,
$sp_hostname       = undef,
$sp_contact        = undef,
$wordpress_image   = "wordpress",
$wordpress_version = "4.1.1", 
$myqsl_version     = "5.7") 
{
   include augeas
   $db_hostname = $db_host ? {
      undef   => "${name}_mysql.docker",
      default => $db_host
   }
   $pwd = hiera("${name}_db_password",'NOT_SET_IN_HIERA')
   file {"/data/${name}": ensure => directory } ->
   file { "/data/${name}/html": ensure => directory } ->
   file { "/data/${name}/shibboleth": ensure => directory } ->
   sunet::docker_run { "${name}_wordpress":
      image       => $wordpress_image,
      imagetag    => $wordpress_version,
      volumes     => ["/data/${name}/html:/var/www/html","/data/${name}/shibboleth:/etc/shibboleth"],
      ports       => ["8080:80"],
      env         => [ "SERVICE_NAME=${name}",
                       "SP_HOSTNAME=${sp_hostname}",
                       "SP_CONTACT=${sp_contact}",
                       "WORDPRESS_DB_HOST=${db_hostname}",
                       "WORDPRESS_DB_USER=${name}",
                       "WORDPRESS_DB_NAME=${name}",
                       "WORDPRESS_DB_PASSWORD=${pwd}" ]
   }

   if (!$db_host) {
      file {"/data/${name}/db": ensure => directory }
      group { 'mysql': ensure => 'present', system => true } ->
      user { 'mysql': ensure => 'present', groups => 'mysql', system => true } ->
      sunet::docker_run { "${name}_mysql":
          image       => "mysql",
          imagetag    => $mysql_version,
          volumes     => ["/data/${name}/db:/var/lib/mysql"],
          env         => ["MYSQL_USER=${name}",
                          "MYSQL_PASSWORD=${pwd}",
                          "MYSQL_ROOT_PASSWORD=${pwd}",
                          "MYSQL_DATABASE=${name}"]
      }
      package {'automysqlbackup': ensure => latest } -> 
      augeas { 'automysqlbackup_settings': 
         incl    => "/etc/default/automysqlbackup",
         lens    => "Shellvars.lns",
         changes => [
            "set USERNAME ${name}",
            "set PASSWORD ${pwd}",
            "set DBHOST ${db_hostname}",
            "set DBNAMES ${name}"
         ]
      }
   }
}
