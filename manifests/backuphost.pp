# configuration for a scp backup host
class sunet::backuphost(
  String        $chroot,
  String        $mountpoint,
  String        $user   = 'backup',
  Array[String] $allow_clients = lookup('backup_pfx', Array[String], undef, ['130.242.125.68', '130.242.121.73']),
) {
  # parameters for sunet/backuphost/cron_free_diskspace.erb
  $free_diskspace_basedir = "${chroot}/incoming"
  $free_diskspace_mountpoint = $mountpoint
  $free_diskspace_percentage = '75'
  $free_diskspace_suffix = '.tar.gz.gpg'

  user {'backup_user':
    name       => $user,
    shell      => '/usr/sbin/rush',
    managehome => true,
    home       => '/home/backup',
  }

  file {
    $chroot:
      ensure  => 'directory',
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      require => [User[$user]
                  ],
      ;
    "${chroot}/incoming":
      ensure  => 'directory',
      mode    => '0770',
      owner   => 'root',
      group   => $user,
      require => [User[$user],
                  File[$chroot]
                  ],
      ;
    '/usr/local/bin/backuphost_remove_old':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      group   => 'root',
      content => template('sunet/backuphost/cron_free_diskspace.erb'),
      ;
    '/etc/rush.rc':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => template('sunet/backuphost/rush.rc.erb'),
      ;
  }

  package { ['rush']:
    ensure     => installed,
  }

  # The chroot needs a /dev/null in it, if $chroot is on /local this won't work
  # (error: Couldn't open /dev/null: Permission denied) since /local is mounted nodev by the puppet-bastion module.
  # This is the best workaŕound I could think of at the moment:
  #
  #   mkdir /root/rushdev
  #   mknod --mode 666 /root/rushdev/null c 1 3
  #   mount --bind /root/rushdev $chroot/dev
  #   echo "/root/rushdev $chroot/dev none bind" >> /etc/fstab
  #
  exec { 'mkchroot_rush':
    command     => "zcat /usr/share/doc/rush/scripts/mkchroot-rush.pl.gz | perl -- - --user ${user} --chroot ${chroot} --tasks etc,dev,bin,lib --binaries /usr/bin/scp --force",
    path        => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
    unless      => "/usr/bin/test -f ${chroot}/usr/bin/scp",
    require     => [File[$chroot],
                    Package['rush'],
                    ],
    environment => 'USER=root',  # this is how mkchroot-rush.pl checks if it is root or not. /dev/null needs this.
  }

  exec { 'mkchroot_rush_libnss':
    # Add missing libnss_files to chroot - otherwise scp won't work
    command => "cp -a /lib/x86_64-linux-gnu/libnss_files* ${chroot}/lib/x86_64-linux-gnu/",
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
    unless  => "/usr/bin/test -f ${chroot}/lib/x86_64-linux-gnu/libnss_files-*",
    require => [Exec['mkchroot_rush'],
                ],
  }

  # cronjob preventing disk becoming full
  sunet::scriptherder::cronjob { 'backuphost-cleanup':
    cmd           => '/usr/local/bin/backuphost_remove_old',
    special       => 'daily',
    ok_criteria   => ['exit_status=0', 'max_age=25h'],
    warn_criteria => ['exit_status=1'],
  }

  $ssh_key_db = lookup('backup_ssh_keys', undef, undef, undef)
  if is_hash($ssh_key_db) {
    sunet::ssh_keys { 'backuphost':
      config   => { $user => keys($ssh_key_db) },
      database => $ssh_key_db,
    }
  } else {
    warning('Hiera key "backup_ssh_keys" not found, or not a hash')
  }

  sunet::misc::ufw_allow { 'allow_backup_pfx_ssh':
    from => $allow_clients,
    port => '22',
  }
}
