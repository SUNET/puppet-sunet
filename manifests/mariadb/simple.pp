# A simple class to setup mariadb
# Simple but elegant class for a more civilized age
class sunet::mariadb::simple(
  String $mariadb_version          = latest,
  String $mariadb_image            = 'docker.sunet.se/drive/mariadb',
  Boolean $new_cluster             = false,
  Boolean $docker_healthcheck      = false,
  Array[Integer] $ports            = [3306, 4444, 4567, 4568],
  Array[String] $dns               = [],
  Boolean $galera                  = true,
  Boolean $nagios_monitoring       = false,
  String  $innodb_buffer_pool_size = '4G',
  Boolean $use_tls                 = false,
  Integer $binlog_retention_hours  = '6',
){
  sunet::mariadb { 'sunet_mariadb_simple':
    mariadb_version         => $mariadb_version,
    mariadb_image           => $mariadb_image,
    new_cluster             => $new_cluster,
    docker_healthcheck      => $docker_healthcheck,
    ports                   => $ports,
    dns                     => $dns,
    galera                  => $galera,
    nagios_monitoring       => $nagios_monitoring,
    innodb_buffer_pool_size => $innodb_buffer_pool_size,
    use_tls                 => $use_tls,
    binlog_retention_hours  => $binlog_retention_hours
  }
}
