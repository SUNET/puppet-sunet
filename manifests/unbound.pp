# Install and configure an unbound DNS resolver
class sunet::unbound(
  Boolean $use_apparmor        = true,
  Boolean $use_sunet_resolvers = true,
  Variant[Boolean, Undef] $disable_resolved_stub = undef,
) {
  package { 'unbound': ensure => 'installed' }

  # Help Puppet understand to use systemd for Ubuntu 16.04 hosts
  if $facts['os']['name'] == 'Ubuntu' and versioncmp($facts['os']['release']['full'], '15.04') >= 0 {
    Service {
      provider => 'systemd',
    }
  }

  if $use_apparmor and versioncmp($facts['os']['release']['full'], '20.04') < 0 {
    include apparmor

    file {
      '/etc/apparmor-cosmos':
        ensure => 'directory',
        ;
      '/etc/apparmor-cosmos/usr.sbin.unbound':
        content => template('sunet/unbound/etc_apparmor_cosmos_usr.sbin.unbound.erb'),
        require => File['/etc/apparmor-cosmos'],
        ;
    }

    apparmor::profile { 'usr.sbin.unbound':
      source => '/etc/apparmor-cosmos/usr.sbin.unbound',
    }

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

  if $facts['os']['name'] == 'Ubuntu'
      and versioncmp($facts['os']['release']['full'], '15.04') >= 0
      and versioncmp($facts['os']['release']['full'], '22.04') < 0 and
      $::facts['sunet_nftables_enabled'] != 'yes' {
    include sunet::systemd_reload

    # replace init.d script with systemd service file
    # Ubuntu 22.04 (ever since 18.04?) has it's own systemd service file - start using it.
    # Also test this on earlier versions where $::sunet_nftables_enabled is 'yes' (through opt-in).
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

  if $facts['os']['name'] == 'Ubuntu' {
    ensure_resource('class', 'sunet::disable_resolved_stub', { disable_resolved_stub => $disable_resolved_stub, })
  } elsif $facts['os']['name'] == 'Debian' {
    file_line { 'base':
      path => '/etc/resolvconf/resolv.conf.d/base',
      line => "nameserver ${::facts['ipaddress_default']}",
    }
  }
}
