class sunet::exabgp::monitor (
   $path       = "/etc/bgp/monitor.d",
   $sleep_time = 2
) {
   file { '/etc/bgp/monitor.d': ensure => directory } ->
   file { '/etc/bgp/monitor':
      ensure   => file,
      mode     => '0755',
      content  => template("sunet/exabgp/monitor.erb")
   }
}

define sunet::exabgp::monitor::url(
   $match = undef,
   $route = undef,
   $url   = undef,
   $prio  = 10,
   $path  = "/etc/bgp/monitor.d"
) {
   require stdlib
   $check_url = $url ? {
      undef   => $name,
      default => $url
   }
   ensure_resource('class','Sunet::Exabgp::Monitor', { path => $path });
   $safe_title = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G');
   file {"${path}/${prio}_${safe_title}": 
      ensure   => file,
      content  => template("sunet/exabgp/monitor/url.erb"),
      mode     => '0755'
   }
}
