# Install and configure an unbound DNS resolver
class sunet::unbound(
  Boolean $use_apparmor        = true,
  Boolean $use_sunet_resolvers = true,
  Variant[Boolean, Undef] $disable_resolved_stub = undef,
) {
  package { 'unbound': ensure => 'installed' }

  # Help Puppet understand to use systemd for Ubuntu 16.04 hosts
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '15.04') >= 0 {
    Service {
      provider => 'systemd',
    }
  }

  if $use_apparmor and versioncmp($::operatingsystemrelease, '20.04') < 0 {
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

  if $::operatingsystem == 'Ubuntu'
      and versioncmp($::operatingsystemrelease, '15.04') >= 0
      and versioncmp($::operatingsystemrelease, '22.04') < 0 and
      $::sunet_nftables_opt_in != 'yes' {
    include sunet::systemd_reload

    # replace init.d script with systemd service file
    # Ubuntu 22.04 (ever since 18.04?) has it's own systemd service file - start using it.
    # Also test this on earlier versions where $::sunet_nftables_opt_in is 'yes'.
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

  # If unbound is installed on a host, it is likely that the intent is for it to be used.
  # If the host has systemd resolved, the standard setting is for resolv.conf to have 'nameservers 127.0.0.53'
  # which won't lead to unbound. If the host runs Docker in a separate network namespace, 127.0.0.53 won't
  # work there. Use a careful approach and only default disabling the stub resolver on Ubuntu >= 22.04, or if
  # the nftables opt-in has been set.
  $_disable_resolved = $disable_resolved_stub ? {
    true => true,
    false => false,
    default => $::sunet_nftables_opt_in == 'yes' or ( $::operatingsystem == 'Ubuntu' and
                                                      versioncmp($::operatingsystemrelease, '22.04') >= 0 )
  }

  if $_disable_resolved {
    $dns_ip = pick($::ipaddress_default, $::ipaddress6_default)
    file {
      '/etc/systemd/resolved.conf.d/':
        ensure => 'directory',
        ;
      '/etc/systemd/resolved.conf.d/100-sunet-disable-stub.conf':
        ensure  => file,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        notify  => Exec['resolved_stub_disable'],
        content => @("END"/n)
        [Resolve]
        DNS=${dns_ip}
        DNSStubListener=no
        |END
        ;
      '/etc/resolv.conf':
        ensure => 'link',
        target => '/run/systemd/resolve/resolv.conf'
        ;
    }
  } else {
    file { '/etc/systemd/resolved.conf.d/100-sunet-disable-stub.conf':
      ensure => 'absent',
      notify => Exec['resolved_stub_enable'],
    }
  }

  exec { 'resolved_stub_enable':
    refreshonly => true,
    command     => 'ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf',
  }
  exec { 'resolved_stub_disable':
    refreshonly => true,
    command     => 'ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf',
  }
}
