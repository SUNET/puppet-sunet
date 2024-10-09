class sunet::glb(
          $zone = undef,
          $geodns_version = 'latest',
          $dnslb_version  = 'latest'
)
{
  file { '/etc/geodns':
      ensure => 'directory'
  }

  file { '/etc/GeoLiteFiles':
      ensure => 'directory'
  }

  $geodns_key = safe_hiera('geodns_license')

  if $geodns_key != 'NOT_SET_IN_HIERA' {

      exec { 'fetch_geodns_db':
        command => "curl -s -o /etc/GeoLiteFiles/GeoLite2-Country.tar.gz \"https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&suffix=tar.gz&license_key=${geodns_key}\" && tar xvzf /etc/GeoLiteFiles/GeoLite2-Country.tar.gz -C /etc/GeoLiteFiles/ --wildcards '*.mmdb' | ln -fs $(xargs echo) /etc/GeoLiteFiles/GeoLite2-Country.mmdb",
        onlyif  => 'test ! -f /etc/GeoLiteFiles/GeoLite2-Country.mmdb'
      }


      sunet::scriptherder::cronjob { 'refresh_geodns':
          cmd           => "curl -s -o /etc/GeoLiteFiles/GeoLite2-Country.tar.gz \"https://download.maxmind.com/app/geoip_download?edition_id=GeoLite2-Country&suffix=tar.gz&license_key=${geodns_key}\" && tar xvzf /etc/GeoLiteFiles/GeoLite2-Country.tar.gz -C /etc/GeoLiteFiles/ --wildcards '*.mmdb' | ln -fs $(xargs echo) /etc/GeoLiteFiles/GeoLite2-Country.mmdb",
          weekday       => '1',
          hour          => '6',
          minute        => '1',
          ok_criteria   => ['exit_status=0'],
          warn_criteria => ['max_age=30m']
      }
  }

  sunet::docker_run { 'geodns':
      image            => 'docker.sunet.se/geodns',
      imagetag         => $geodns_version,
      volumes          => ['/etc/geodns:/etc/geodns','/etc/GeoLiteFiles:/usr/share/GeoIP'],
      ports            => ["${::ipaddress_default}:53:5353/udp","${::ipaddress_default}:53:5353"],
      command          => '-port 5353',
      extra_parameters => ['--security-opt seccomp=unconfined'],
  }
  sunet::docker_run { 'dnslb':
      image            => 'docker.sunet.se/dnslb',
      imagetag         => $dnslb_version,
      volumes          => ['/etc/geodns:/etc/geodns'],
      env              => ["ZONE=${zone}"],
      extra_parameters => ['--security-opt seccomp=unconfined'],
   }
   ufw::allow { 'allow-dns-udp':
      ip    => $::ipaddress_default,
      port  => '53',
      proto => 'udp',
   }
   ufw::allow { 'allow-dns-tcp':
      ip    => $::ipaddress_default,
      port  => '53',
      proto => 'tcp',
   }
   sunet::nagios::nrpe_check_process { 'geodns': }
}
