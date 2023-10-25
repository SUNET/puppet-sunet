# Make sure molly-guard is installed, and have it shut down exabgp gracefully.
define sunet::lb::exabgp::molly_guard(
  String $service_name,
) {
  ensure_resource('package', 'molly-guard', {ensure => 'installed'})

  file {
    '/etc/molly-guard/run.d/50-shutdown-exabgp':
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => Package['molly-guard'],
      content => inline_template(@("END"/$n))
      #!/bin/sh
      #
      # Shut down exabgp and wait for a couple of seconds. Created by Puppet (sunet::lb::exabgp).
      #

      set -e

      [ -f "\$MOLLYGUARD_SETTINGS" ] && . "\$MOLLYGUARD_SETTINGS"

      if [ \$MOLLYGUARD_DO_NOTHING = 1 ]; then
          echo "Would have shut down ${service_name} now"
          exit 0
      fi

      echo -n "Shutting down ${service_name}..."
      service ${service_name} stop
      echo -n 'waiting...'
      sleep 2
      echo 'done'
      |END
      ;
  }
}
