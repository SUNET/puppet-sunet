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

class sunet::tinyq::component::library($ensure = 'file') {
  sunet::tinyq::component { 'library': order => '10', ensure => $ensure }
}

class sunet::tinyq::component::daily_facter($ensure = 'file') {
  sunet::tinyq::component { 'daily_facter': ensure => $ensure }
}
