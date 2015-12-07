define sunet::pyff($version = "latest", $image = "docker.sunet.se/pyff", $dir = "/opt/metadata", $ip = undef) {
   $ip_addr = $ip ? {
      undef   => "",
      default => "${ip}:"
   }
   sunet::docker_run{"pound-${name}":
      image    => "docker.sunet.se/pound",
      imagetag => "latest",
      volumes  => ["/etc/ssl:/etc/ssl"],
      env      => ["BACKEND_PORT=tcp://varnish-${name}.docker:80"],
      ports    => ["${ip_addr}443:443"],
      start_on => "docker-varnish-${name}"
   }
   sunet::docker_run {"varnish-${name}":
      image    => 'docker.sunet.se/varnish',
      env      => ["BACKEND_PORT=tcp://pyff-${name}.docker:8080"],
      ports    => ['${ip_addr}80:80'],
      start_on => "docker-pyff-${name}"
   }
   sunet::docker_run {"pyff-${name}":
      image     => $image,
      imagetag => $version,
      volumes   => ["$dir:/opt/metadata"],
      env       => ['DATADIR=/opt/metadata','LOGLEVEL=INFO']
   }
}
