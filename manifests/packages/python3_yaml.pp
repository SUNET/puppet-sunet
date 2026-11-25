# Python bindings for YAML.
class sunet::packages::python3_yaml {
  $package_name = $facts['os']['family'] ? {
    'RedHat' => 'python3-pyyaml',
    default  => 'python3-yaml',
  }
  package { $package_name: ensure => installed }
}
