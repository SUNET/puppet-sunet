# apache2_utils.pp
class sunet::packages::apache2_utils {
  package     { 'apache2-utils':
    ensure => installed,
  }
}
