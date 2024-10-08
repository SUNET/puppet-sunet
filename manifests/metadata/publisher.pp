class sunet::metadata::publisher(
    Array   $allow_clients=['any'],
    $keyname=undef,
    String  $dir='/var/www/html',
    $src=undef)
{
  $_keyname = $keyname ? {
      undef   => $facts['networking']['fqdn'],
      default => $keyname
  }
  if ($src) {
      file {'/usr/local/bin/mirror-mdq.sh':
        ensure  => file,
        mode    => '0755',
        content => template('sunet/pyff/mirror-mdq.sh')
      }
      -> sunet::scriptherder::cronjob { "${name}-sync":
        cmd           => "env RSYNC_ARGS='--chown=www-data:www-data --chmod=D0755,F0664 --xattrs' /usr/local/bin/mirror-mdq.sh ${src} ${dir}",
        minute        => '*/5',
        ok_criteria   => ['exit_status=0'],
        warn_criteria => ['max_age=30m']
      }
  }
  $ssh_key = lookup(publisher_ssh_key, undef, undef, undef)
  $ssh_key_type = lookup(publisher_ssh_key_type, undef, undef, undef)
  if ($ssh_key and $ssh_key_type) {
      sunet::rrsync {$dir:
        ro           => false,
        ssh_key      => $ssh_key,
        ssh_key_type => $ssh_key_type
      }
  }
  file { '/var/www': ensure => directory, mode => '0755' }
  -> file { '/var/www/html': ensure => directory, mode => '0755', owner => 'www-data', group =>'www-data' }
  -> package {['lighttpd','attr']: ensure => latest }
  -> exec {'enable-ssl':
      command => '/usr/sbin/lighttpd-enable-mod ssl',
      onlyif  => 'test ! -h /etc/lighttpd/conf-enabled/*ssl*'
  }
  -> file {'/etc/lighttpd/server.pem':
      ensure => 'link',
      target => "/etc/ssl/private/${_keyname}.pem"
  }
  -> apparmor::profile { 'usr.sbin.lighttpd': source => '/etc/apparmor-cosmos/usr.sbin.lighttpd' }
  -> file {'/etc/lighttpd/conf-enabled/99-mime-xattr.conf':
      ensure  => file,
      mode    => '0640',
      owner   => 'root',
      group   => 'root',
      content => inline_template("mimetype.use-xattr = \"enable\"\n")
  }
  -> service {'lighttpd': ensure => running }
  -> sunet::misc::ufw_allow {'allow-lighttpd':
      from => $allow_clients,
      port => 443
  }
  -> sunet::nagios::nrpe_check_fileage {'metadata_aggregate':
      filename     => '/var/www/html/entities/index.html', # yes this is correct
      warning_age  => '600',
      critical_age => '86400'
  }
}
