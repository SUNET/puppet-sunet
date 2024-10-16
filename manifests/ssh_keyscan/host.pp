# ssh_keyscan::host
define sunet::ssh_keyscan::host (
  Array $aliases = [],
  Optional[String] $address = undef,
) {
  $hostsfile = '/etc/ssh/sunet_keyscan_hosts.txt'
  ensure_resource('class','sunet::ssh_keyscan', {hostsfile => $hostsfile})
  $the_address = $address ? {
    undef   => dns_lookup($title),
    default => [$address]
  }
  if ($the_address !~ Array) {
    fail("Variable $the_address is not an array")
  }
  $the_aliases = concat(any2array($aliases),[$title],[$the_address])
  concat::fragment {"${title}_sunet_keyscan":
    target  => $hostsfile,
    content => inline_template("<%= @the_address[0] %> <%= @the_aliases.join(',') %>\n"),
    order   => '20',
  }
}
