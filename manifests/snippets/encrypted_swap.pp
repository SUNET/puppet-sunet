# Encrypted swap
define sunet::snippets::encrypted_swap() {

  package { 'ecryptfs-utils':
    ensure => 'installed'
  }
  -> exec {'sunet_ecryptfs_setup_swap':
    command => '/usr/bin/ecryptfs-setup-swap -f',
    onlyif  => 'grep swap /etc/fstab | grep -ve ^# -e cryptswap | grep -q swap',
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }

}
