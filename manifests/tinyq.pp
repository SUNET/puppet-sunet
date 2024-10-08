class sunet::tinyq() {
  apt::ppa { 'ppa:sunet/tinyq': }
  -> package { 'tinyq': ensure => latest }
  -> service { 'tinyq': ensure => running }
}
