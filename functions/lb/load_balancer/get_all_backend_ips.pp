# Get a list of all the instances backends - they should all be able to contact the API
function sunet::lb::load_balancer::get_all_backend_ips(
  Hash[String, Hash] $config,
) >> Array[String] {
  if has_key($config['load_balancer'], 'websites') {
    $websites = $config['load_balancer']['websites']
  } elsif has_key($config['load_balancer'], 'websites2') {
    # name used during migration
    $websites = $config['load_balancer']['websites2']
  } else {
    fail('Load balancer config contains neither "websites" nor "websites2"')
  }

  $all_ips = map($websites) | $instance_name, $v1 | {
    if has_key($v1, 'backends') {
      map($v1['backends']) | $backend_name, $v2 | {
        map($v2) | $backend_fqdn, $v3 | {
          has_key($v3, 'ips') ? {
            true => $v3['ips'],
            false => []
          }
        }
      }
    }
  }

  $uniq = flatten($all_ips).unique
  $uniq
}
