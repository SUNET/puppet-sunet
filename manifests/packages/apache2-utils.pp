# apache2_utils.pp
define sunet::packages::apache2_utils {
  package     { 'apache2-utils':
    ensure => installed,
  }
}
