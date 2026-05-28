# Convenience function to load a value from the load_balancer section of the config
function sunet::lb::load_balancer::get_config(
  Hash[String, Hash] $config,
  String $name,
  $default = undef
) {
  $name in $config['load_balancer'] ? {
    true  => $config['load_balancer'][$name],
    false => $default,
  }
}
