# A simple class to setup mariadb
# Simple but elegant class for a more civilized age
class sunet::mariadb::simple(
  String $mariadb_version=latest,
  Integer $bootstrap=0,
  Array[Integer] $ports = [3306, 4444, 4567, 4568],
  Array[String] $dns = [],
){
  sunet::mariadb { 'sunet_mariadb_simple':
    mariadb_version => $mariadb_version,
    bootstrap       => $bootstrap,
    ports           => $ports,
    dns             => $dns,
  }
}
