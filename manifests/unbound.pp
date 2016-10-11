# Install and configure an unbound DNS resolver
class sunet::unbound(
  $use_apparmor        = true,
  $use_sunet_resolvers = true,
) {
  package { 'unbound': ensure => 'installed' }

  if $use_apparmor {
    include apparmor

    file {
      '/etc/apparmor-cosmos':
        ensure => 'directory',
        ;
      '/etc/apparmor-cosmos/usr.sbin.unbound':
        content => template('sunet/unbound/etc_apparmor_cosmos_usr.sbin.unbound.erb'),
        require => File['/etc/apparmor-cosmos'],
        ;
    } ->

    apparmor::profile { 'usr.sbin.unbound':
      source => '/etc/apparmor-cosmos/usr.sbin.unbound',
    } ->

    service { 'unbound':
      ensure  => 'running',
      enable  => true,
      require => Package['unbound'],
    }
  } else {
    service { 'unbound':
      ensure  => 'running',
      enable  => true,
      require => Package['unbound'],
    }
  }

  if $use_sunet_resolvers {
    file { '/etc/unbound/unbound.conf.d/unbound-sunet-resolvers.conf':
      path    => '/etc/unbound/unbound.conf.d/unbound-sunet-resolvers.conf',
      owner   => 'root',
      mode    => '0644',
      content => template('sunet/unbound/unbound-sunet-resolvers.conf.erb'),
      notify  => Service['unbound'],
      require => Package['unbound'],
    }
  }

  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
    include sunet::systemd_reload

    # replace init.d script with systemd service file
    file {
      '/etc/init.d/unbound':
        ensure => 'absent',
        ;
      '/etc/insserv.conf.d/unbound':
        ensure => 'absent',
        ;
      '/etc/systemd/system/unbound.service':
        content => template('sunet/unbound/sunet_unbound.service.erb'),
        notify  => [Class['sunet::systemd_reload'],
                    Service['unbound'],
                    ],
        ;
    }
  }
}
