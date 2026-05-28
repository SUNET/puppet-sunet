# Get a list of all the instances frontend addresses
function sunet::lb::load_balancer::get_all_frontend_ips(
  Hash[String, Any] $config,
) >> Array[String] {
  if ! 'frontends' in $config {
    fail('Website config contains no frontends section')
  }
  $all_ips = map($config['frontends']) | $frontend_fqdn, $v | {
    # k should be a frontend FQDN and $v a hash with ips in it:
    #   $v = {ips => [192.0.2.1]}}
    ($v =~ Hash and 'ips' in $v) ? {
      true  => $v['ips'],
      false => []
    }
  }

  $uniq = flatten($all_ips).unique
  $uniq
}
