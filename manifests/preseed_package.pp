# preseed_package
define sunet::preseed_package ($ensure, $options = {}) {
  file { "/tmp/${name}.preseed":
    content => template("sunet/preseed/${name}"),
    mode    => '0600',
    backup  => false,
  }
  -> package { $name:
    ensure       => $ensure,
    responsefile => "/tmp/${name}.preseed",
    require      => File["/tmp/${name}.preseed"],
  }
}
