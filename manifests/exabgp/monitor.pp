class sunet::exabgp::monitor (
  String  $route,
  String  $path       = '/etc/bgp/monitor.d',
  Integer $sleep_time = 2
) {
   file { '/etc/bgp/monitor.d': ensure => directory } ->
   file { '/etc/bgp/monitor':
      ensure   => file,
      mode     => '0755',
      content  => template("sunet/exabgp/monitor.erb")
   }
}

define sunet::exabgp::monitor::url(
  String           $url,
  String           $route,
  Optional[String] $match = undef,   # string to look for on the URL
  Integer          $prio  = 10,
  String           $path  = '/etc/bgp/monitor.d',
) {
   require stdlib
   $check_url = $url ? {
      undef   => $name,
      default => $url
   }
   ensure_resource('class','Sunet::Exabgp::Monitor', { path => $path, route => $route, });
   $safe_title = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G');
   file {"${path}/${prio}_${safe_title}":
      ensure   => file,
      content  => template('sunet/exabgp/monitor/url.erb'),
      mode     => '0755'
   }
}
