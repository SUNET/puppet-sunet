# pyff
define sunet::pyff(
  $version = 'latest',
  $image = 'docker.sunet.se/pyff',
  $dir = '/opt/metadata',
  $ssl_dir = '/etc/ssl',
  $pyffd_args = '',
  $pyffd_loglevel = 'INFO',
  $acme_tool_uri = undef,
  $pound_and_varnish = true,
  $volumes = [],
  $docker_run_extra_parameters = [],
  $pipeline = 'mdx.fd',
  $port = '80',
  $ensure = 'present',
  $langs = 'en',
  $ip = undef) {
  $ip_addr = $ip ? {
      undef   => '',
      default => "${ip}:"
  }
  $sanitised_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')
  if ($pound_and_varnish) {
      sunet::docker_run{"pound-${sanitised_title}":
        ensure           => $ensure,
        image            => 'docker.sunet.se/pound',
        imagetag         => 'latest',
        volumes          => ["${ssl_dir}:/etc/ssl"],
        env              => ["BACKEND_PORT=tcp://varnish-${sanitised_title}.docker:${port}"],
        ports            => ["${ip_addr}443:443"],
        depends          => ["varnish-${sanitised_title}"],
        extra_parameters => $docker_run_extra_parameters
      }
      $acme_env = $acme_tool_uri ? {
        undef    => [],
        default  => ["ACME_PORT=${acme_tool_uri}"]
      }
      sunet::docker_run {"varnish-${sanitised_title}":
        ensure  => $ensure,
        image   => 'docker.sunet.se/varnish',
        env     => flatten([["BACKEND_PORT=tcp://pyff-${sanitised_title}.docker:8080"],$acme_env]),
        ports   => ["${ip_addr}${port}:80"],
        depends => ["pyff-${sanitised_title}"]
      }
  } else {
      sunet::docker_run{"pound-${sanitised_title}": image => 'docker.sunet.se/pound', ensure => absent }
      sunet::docker_run {"varnish-${sanitised_title}": image => 'docker.sunet.se/varnish', ensure => absent }
  }
  $pyff_ports = $pound_and_varnish ? {
      true        => [],
      false       => ["${ip_addr}${port}:8080"]
  }
  sunet::docker_run {"pyff-${sanitised_title}":
      ensure           => $ensure,
      image            => $image,
      imagetag         => $version,
      volumes          => flatten([$volumes,["${dir}:${dir}"]]),
      ports            => $pyff_ports,
      env              => [
                            "DATADIR=${dir}",
                            "EXTRA_ARGS=${pyffd_args}",
                            "PIPELINE=${pipeline}",
                            "LOGLEVEL=${pyffd_loglevel}",
                            "PYFF_LANGS=${langs}"
                          ],
      extra_parameters => $docker_run_extra_parameters
  }
  file {'/usr/local/bin/mirror-mdq.sh':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/pyff/mirror-mdq.sh')
  }
}
