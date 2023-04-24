class sunet::packages::yq {
    include 'sunet::packages':python3_pip
    include 'sunet::packages':jq
    package { 'yq':
      ensure   => installed,
      provider => 'pip3',
      require  => Package['python3-pip', 'jq']
    }
}
