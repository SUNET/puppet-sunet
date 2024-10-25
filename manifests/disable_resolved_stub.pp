# Disable/enable resolved stub
class sunet::disable_resolved_stub(
  Variant[Boolean, Undef] $disable_resolved_stub = undef,
  String $dns_ip                                 = pick($facts['networking']['ip'], $facts['networking']['ip6']),
) {
  # If unbound is installed on a host, it is likely that the intent is for it to be used.
  # If the host has systemd resolved, the standard setting is for resolv.conf to have 'nameservers 127.0.0.53'
  # which won't lead to unbound. If the host runs Docker in a separate network namespace, 127.0.0.53 won't
  # work there. Use a careful approach and only default disabling the stub resolver on Ubuntu >= 22.04, or if
  # the nftables opt-in has been set.
  $_disable_resolved = $disable_resolved_stub ? {
    true => true,
    false => false,
    default => $::facts['sunet_nftables_enabled'] == 'yes'
  }

  if $_disable_resolved {
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
