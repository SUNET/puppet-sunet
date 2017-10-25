require stdlib
require concat

class sunet::ssh_keyscan(
  String $hostsfile,
  String $keyfile = '/etc/ssh/ssh_known_hosts',
) {
  exec {'sunet_ssh-keyscan':
    command     => "ssh-keyscan -f ${hostsfile} > ${keyfile}.scan && mv ${keyfile}.scan ${keyfile}",
    refreshonly => true,
    subscribe   => File[$hostsfile],
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

define sunet::ssh_keyscan::host (
  Array $aliases = [],
  Optional[String] $address = undef,
) {
  $hostsfile = '/etc/ssh/sunet_keyscan_hosts.txt'
  ensure_resource('class','sunet::ssh_keyscan', {hostsfile => $hostsfile})
  $the_address = $address ? {
    undef   => dnsLookup($title),
    default => [$address]
  }
  validate_array($the_address)
  $the_aliases = concat(any2array($aliases),[$title],[$the_address])
  concat::fragment {"${title}_sunet_keyscan":
    target  => $hostsfile,
    content => inline_template("<%= @the_address[0] %> <%= @the_aliases.join(',') %>\n"),
    order   => '20',
  }
}
