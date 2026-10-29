# ssl_cert.pp
class sunet::packages::ssl_cert {
  package     { 'ssl-cert':
    ensure => installed,
  }
}
