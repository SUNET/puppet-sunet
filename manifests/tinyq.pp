class sunet::tinyq() {
   apt::ppa { 'ppa:sunet/tinyq': } ->
   package { 'tinyq': ensure => latest } ->
   service { 'tinyq': ensure => running }
}

define sunet::tinyq::component($config = {}, $template = undef, $order = '99', $ensure = 'file') {
   $_template = $template ? {
      undef   => $name,
      default => $template
   }
   file {"/etc/tinyq/tinyq.d/${order}-${name}.tq":
      ensure  => $ensure,
      content => template("sunet/tinyq/${_template}.erb"),
      notify  => Service['tinyq']
   }
}

class sunet::tinyq::library($ensure = 'file') {
   sunet::tinyq::component { 'library': $order => "10", $ensure => $ensure }
}

class sunet::tinyq::daily_facter($ensure = 'file') {
   sunet::tinyq::component { 'daily_facter': $ensure => $ensure }
}
