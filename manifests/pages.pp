class sunet::pages($host='127.0.0.1',$port='5000',$version='latest') {
   $config = lookup('sunet_pages_sites', undef, undef, undef)
   file { ['/var/www','/var/cache/sunetpages']: ensure => 'directory' } ->
   user {'www-data': ensure => present, system => true } ->
   sunet::docker_run { 'sunet-pages-api':
      image       => 'docker.sunet.se/sunet-pages-api',
      imagetag    => $version,
      volumes     => ['/var/www:/var/www',
                      '/var/cache/sunetpages:/var/cache/sunetpages',
                      "/usr/bin/docker:/usr/bin/docker:ro",
                      "/var/run/docker.sock:/var/run/docker.sock:rw",
                      "/root/.ssh:/root/.ssh:ro",
                      "/etc/ssh/config:/etc/ssh/config:ro",
                      "/etc/ssh/ssh_known_hosts:/etc/ssh/ssh_known_hosts:ro",
                      '/etc/sunet-pages.yaml:/etc/sunet-pages.yaml:ro'],
      env         => ['SUNET_PAGES_CONFIG=/etc/sunet-pages.yaml'],
      ports       => ["$host:$port:5000"]
   }
   file {"/etc/sunet-pages.yaml":
      content => inline_template("<%= @config.to_yaml %>\n"),
      notify  => Sunet::Docker_run['sunet-pages-api']
   }
}
