# Install and configure NTP service
class sunet::ntp(
  $disable_pool_ntp_org = false,
  $set_servers = [],
  $add_servers = [],  # backwards compatibility
) {
  # Help Puppet understand to use systemd for Ubuntu 16.04 hosts
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
    Service {
      provider => 'systemd',
    }
  }

  # Install updated augeas lens from https://github.com/hercules-team/augeas/blob/master/lenses/ntp.aug
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '16.04') <= 0 {
    file {
      '/usr/share/augeas/lenses/dist/ntp.aug':
        content => template("sunet/ntp/ntp.aug.erb"),
        ;
    }
  }

  package { 'ntp': ensure => 'installed' }
  service { 'ntp':
    name       => 'ntp',
    ensure     => running,
    enable     => true,
    hasrestart => true,
    require => Package['ntp'],
  }

  # Don't use pool.ntp.org servers, but rather DHCP provided NTP servers
  $_disable_pool = $disable_pool_ntp_org ? {
    true => ['rm pool[.]'],
    false => [],
  }

  # in cases where DHCP does not provide servers, or the machinery doesn't
  # work well (Ubuntu 16.04, looking at you), add some servers manually
  $_set_servers = map(flatten([$set_servers, $add_servers])) |$index, $server| {
    sprintf('set server[%s] %s', $index + 1, $server)
  }
  $changes = flatten([$_disable_pool,
                      $_set_servers ? {
                        [] => [],
                        default => ['rm server[.]',
                                    $_set_servers],
                      },])

  if $changes != [] {
    include augeas

    augeas { 'ntp.conf':
      context => '/files/etc/ntp.conf',
      changes => $changes,
      require => Package['ntp'],
      notify  => Service['ntp'],
    }
  }

  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
    include sunet::systemd_reload

    # replace init.d script with systemd service file to get Restart=always
    file {
      '/etc/systemd/system/ntp.service':
        content => template('sunet/ntp/ntp.service.erb'),
        notify  => [Class['sunet::systemd_reload'],
                    Service['ntp'],
                    ],
        ;
    }
  }
}
