class sunet::packages::yq {
    include sunet::packages:python3_pip
    package { 'yq': 
      ensure => installed,
      provider => "pip3",
      require => Package["python3-pip"]
    }
}
