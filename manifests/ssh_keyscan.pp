# ssh-keyscan
class sunet::ssh_keyscan(
  String $hostsfile,
  String $keyfile = '/etc/ssh/ssh_known_hosts',
) {
  exec {'sunet_ssh-keyscan':
    command     => "ssh-keyscan -f ${hostsfile} > ${keyfile}.scan && mv ${keyfile}.scan ${keyfile}",
    refreshonly => false,
    subscribe   => Concat[$hostsfile],
  }

  concat {$hostsfile:
    owner => root,
    group => root,
    mode  => '0640',
  }
  concat::fragment {"${hostsfile}_header":
    target  => $hostsfile,
    content => "# do not edit by hand - maintained by sunet::ssh_keyscan\n",
    order   => '10',
  }

  # AppArmor profile on Ubuntu 26.04+ restricts ssh-keyscan to network only.
  # Add local override to permit reading the hosts file.
  if $facts['os']['name'] == 'Ubuntu' and
      versioncmp($facts['os']['release']['full'], '26.04') >= 0 {
    file { '/etc/apparmor.d/local/ssh-keyscan':
      ensure  => file,
      owner   => root,
      group   => root,
      mode    => '0644',
      content => "r ${hostsfile},\n",
      notify  => Exec['apparmor_reload_ssh-keyscan'],
    }
    exec { 'apparmor_reload_ssh-keyscan':
      command     => 'apparmor_parser -r /etc/apparmor.d/ssh-keyscan',
      refreshonly => true,
      path        => ['/sbin', '/usr/sbin', '/usr/bin'],
      onlyif      => 'test -f /etc/apparmor.d/ssh-keyscan',
      before      => Exec['sunet_ssh-keyscan'],
    }
  }
}
