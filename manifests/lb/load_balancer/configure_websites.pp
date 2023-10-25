# Create a sunet::lb::load_balancer::website resource for every website in the config
define sunet::lb::load_balancer::configure_websites(Hash[String, Hash] $websites, String $basedir, String $confdir, String $scriptdir)
{
  each($websites) | $site, $config | {
    create_resources('sunet::lb::load_balancer::website', {$site => {}}, {
      'basedir'         => $basedir,
      'confdir'         => $confdir,
      'scriptdir'       => $scriptdir,
      'config'          => $config,
      })
  }
}
