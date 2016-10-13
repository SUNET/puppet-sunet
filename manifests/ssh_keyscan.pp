require stdlib
require concat

class sunet::ssh_keyscan {
   exec {'ssh-keyscan':
      command     => 'ssh-keyscan -f /etc/ssh/sunet_keyscan_hosts.txt > /etc/ssh/ssh_known_hosts',
      refreshonly => true
   }
   concat {"/etc/ssh/sunet_keyscan_hosts.txt":
      owner  => root,
      group  => root,
      mode   => '0644',
   } ->
   concat::fragment {"/etc/ssh/sunet_keyscan_hosts.txt_header":
      target  => "/etc/ssh/sunet_keyscan_hosts.txt",
      content => "# do not edit by hand - maintained by sunet::ssh_keyscan",
      order   => '10',
      notify  => Exec['ssh-keyscan']
   }
}

define sunet::ssh_keyscan::host ($aliases = [], $address = undef) {
   ensure_resource('class','sunet::ssh_keyscan',{})
   $the_address = $address ? {
      undef   => dnsLookup($title),
      default => $address
   }
   $the_aliases = concat(any2array($aliases),[$title],[$the_address])
   concat::fragment {"${title}_sunet_keyscan":
      target  => "/etc/ssh/sunet_keyscan_hosts.txt",
      content => inline_template("<%= the_address %> <%= the_aliases.join(',') %>"),
      order   => '20',
      notify  => Exec['ssh-keyscan']
   }
}
