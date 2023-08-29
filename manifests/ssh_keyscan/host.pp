# Keyscan host
define sunet::ssh_keyscan::host (
  Array $aliases = [],
  Optional[String] $address = undef,
) {
  require stdlib
  require concat
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
