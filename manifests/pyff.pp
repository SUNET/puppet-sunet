define sunet::pyff($version = "latest", $image = "docker.sunet.se/pyff", $dir = "/opt/metadata", $ip = undef) {
   $ip_addr = $ip ? {
      undef   => "",
      default => "${ip}:"
   }
   $sanitised_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
   sunet::docker_run{"pound-${sanitized_title}":
      image    => "docker.sunet.se/pound",
      imagetag => "latest",
      volumes  => ["/etc/ssl:/etc/ssl"],
      env      => ["BACKEND_PORT=tcp://varnish-${sanitized_title}.docker:80"],
      ports    => ["${ip_addr}443:443"],
      start_on => "docker-varnish-${sanitized_title}"
   }
   sunet::docker_run {"varnish-${sanitized_title}":
      image    => 'docker.sunet.se/varnish',
      env      => ["BACKEND_PORT=tcp://pyff-${sanitized_title}.docker:8080"],
      ports    => ["${ip_addr}80:80"],
      start_on => "docker-pyff-${sanitized_title}"
   }
   sunet::docker_run {"pyff-${sanitized_title}":
      image     => $image,
      imagetag => $version,
      volumes   => ["$dir:/opt/metadata"],
      env       => ['DATADIR=/opt/metadata','LOGLEVEL=INFO']
   }
}
