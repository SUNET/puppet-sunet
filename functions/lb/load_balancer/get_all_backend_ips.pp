# Get a list of all the instances backends - they should all be able to contact the API
function sunet::lb::load_balancer::get_all_backend_ips(
  Hash[String, Hash] $config,
) >> Array[String] {
  if 'websites' in $config['load_balancer'] {
    $websites = $config['load_balancer']['websites']
  } else {
    fail('Load balancer config does not contain "websites"')
  }

  $all_ips = map($websites) | $instance_name, $v1 | {
    if 'backends' in $v1 {
      map($v1['backends']) | $backend_name, $v2 | {
        map($v2) | $backend_fqdn, $v3 | {
          'ips' in $v3 ? {
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
