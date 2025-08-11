# load balancer
define sunet::frontend::load_balancer::configure_websites($websites, $basedir, $confdir)
{
  create_resources('sunet::frontend::load_balancer::website', $websites, {
    'basedir' => $basedir,
    'confdir' => $confdir,
    })
}

