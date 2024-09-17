# Mariadb cluster definefor SUNET
define sunet::mariadb(){
  warning('Please transition to the class "sunet::mariadb::server" instead of this define')
  require sunet::mariadb::server
}
