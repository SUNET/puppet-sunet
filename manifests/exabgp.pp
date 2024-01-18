define sunet::exabgp(
  Array   $extra_arguments = [],
  String  $config          = '/etc/bgp/exabgp.conf',
  String  $version         = 'latest',
  String  $volume          = '/etc/bgp',
  Array   $docker_volumes  = [],
) {
   $safe_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G');
   sunet::docker_run {"${safe_title}_exabgp":
      image       => 'docker.sunet.se/sunet/docker-sunet-exabgp',
      imagetag    => $version,
      volumes     => flatten(["${volume}:${volume}:ro", $docker_volumes]),
      net         => 'host',
      command     => join(flatten([$config,$extra_arguments])," ")
   }

   sunet::snippets::no_icmp_redirects {"no_icmp_redirects_${safe_title}": }

   ensure_resource('package', 'molly-guard', {ensure => 'installed'})

   $svc_name = "docker-${safe_title}_exabgp"
   file {
     '/etc/molly-guard/run.d/50-shutdown-exabgp':
       owner   => 'root',
       group   => 'root',
       mode    => '0755',
       require => Package['molly-guard'],
       content => inline_template(@("END"/$n))
       #!/bin/sh
       #
       # Shut down exabgp and wait for a couple of seconds. Created by Puppet (sunet::exabgp).
       #

       set -e

       [ -f "\$MOLLYGUARD_SETTINGS" ] && . "\$MOLLYGUARD_SETTINGS"

       if [ \$MOLLYGUARD_DO_NOTHING = 1 ]; then
           echo "Would have shut down ${svc_name} now"
           exit 0
       fi

       echo -n "Shutting down ${svc_name}..."
       service ${svc_name} stop
       echo -n 'waiting...'
       sleep 2
       echo 'done'
       |END
       ;
   }
}
