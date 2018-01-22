define sunet::pyff(
   $version = "latest",
   $image = "docker.sunet.se/pyff",
   $dir = "/opt/metadata",
   $ssl_dir = "/etc/ssl",
   $pyffd_args = "",
   $pyffd_loglevel = "INFO",
   $acme_tool_uri = undef,
   $pound_and_varnish = true,
   $pipeline = "mdx.fd",
   $ip = undef) {
   $ip_addr = $ip ? {
      undef   => "",
      default => "${ip}:"
   }
   $sanitised_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
   if ($pound_and_varnish) {
      sunet::docker_run{"pound-${sanitised_title}":
         image    => "docker.sunet.se/pound",
         imagetag => "latest",
         volumes  => ["${ssl_dir}:/etc/ssl"],
         env      => ["BACKEND_PORT=tcp://varnish-${sanitised_title}.docker:80"],
         ports    => ["${ip_addr}443:443"],
         depends  => ["varnish-${sanitised_title}"]
      }
      $acme_env = $acme_tool_uri ? {
         undef    => [],
         default  => ["ACME_PORT=$acme_tool_uri"]
      }
      sunet::docker_run {"varnish-${sanitised_title}":
         image    => 'docker.sunet.se/varnish',
         env      => flatten([["BACKEND_PORT=tcp://pyff-${sanitised_title}.docker:8080"],$acme_env]),
         ports    => ["${ip_addr}80:80"],
         depends  => ["pyff-${sanitised_title}"]
      }
   }
   $pyff_ports = $pound_and_varnish ? {
      true        => [],
      false       => ["${ip_addr}80:8080"]
   }
   sunet::docker_run {"pyff-${sanitised_title}":
      image       => $image,
      imagetag    => $version,
      volumes     => ["$dir:$dir"],
      ports       => $pyff_ports,
      env         => ["DATADIR=$dir","EXTRA_ARGS=$pyffd_args","PIPELINE=$pipeline","LOGLEVEL=$pyffd_loglevel"]
   }
}
