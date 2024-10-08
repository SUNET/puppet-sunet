class sunet::metadata::signer($dest_host=undef,$dest_dir='',$version='1.1.4') {
  package { ['xsltproc','libxml2-utils','attr']: ensure => latest }
  -> sunet::pyff {$name:
      version                     => $version,
      pound_and_varnish           => false,
      pipeline                    => "${name}.fd",
      volumes                     => ['/etc/credentials:/etc/credentials'],
      docker_run_extra_parameters => ['--log-driver=syslog']
  }
  if ($dest_host) {
      sunet::ssh_host_credential { "${name}-publish-credential":
        hostname    => $dest_host,
        username    => 'root',
        group       => 'root',
        manage_user => false,
        ssh_privkey => safe_hiera('publisher_ssh_privkey')
      }
      -> sunet::scriptherder::cronjob { "${name}-publish":
        cmd           => "env RSYNC_ARGS='--chown=www-data:www-data --chmod=D0755,F0664 --xattrs' /usr/local/bin/mirror-mdq.sh http://172.16.0.2 root@${dest_host}:${dest_dir}",
        minute        => '*/5',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=30m']
      }
  }
}
