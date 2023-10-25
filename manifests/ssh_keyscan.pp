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
}
