# Install and configure an unbound DNS resolver
class sunet::unbound(
  $use_apparmor        => true,
  $use_sunet_resolvers => true,
) {
  package { 'unbound': ensure => 'installed' }

  if $use_apparmor {
    include apparmor

    apparmor::profile { 'usr.sbin.unbound':
      source => '/etc/apparmor-cosmos/usr.sbin.unbound',
    } ->

    service { 'unbound':
      ensure  => 'running',
      require => Package['unbound'],
    }
  } else {
    service { 'unbound':
      ensure  => 'running',
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
}
