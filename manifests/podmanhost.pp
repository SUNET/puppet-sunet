# Install docker from https://get.docker.com/ubuntu
class sunet::podmanhost(
) {
  include sunet::packages::podman
  include stdlib
  file { '/etc/containers/storage.conf':
    ensure  => file,
    content => template('sunet/podmanhost/storage.conf.erb'),
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
  }
  if $::facts['sunet_nftables_enabled'] == 'yes' {
    ensure_resource ('class','sunet::nftables::init', {})
    file {
      '/etc/nftables/conf.d/200-sunet_podmanhost.nft':
        ensure  => file,
        mode    => '0400',
        content => template('sunet/podmanhost/200-dockerhost_nftables.nft.erb'),
        notify  => Service['nftables'],
        ;
    }
  }

}
