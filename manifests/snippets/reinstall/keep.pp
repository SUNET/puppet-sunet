# Keep
define sunet::snippets::reinstall::keep() {
   $safe_name = regsubst($name, '[^0-9A-Za-z_]', '_', 'G')
   ensure_resource('file','/etc/sunet-reinstall.keep',{owner=>'root',group=>'root',mode=>'0644'})
   exec { "preserve_${safe_name}_during_reinstall":
      command => "echo $name >> /etc/sunet-reinstall.keep",
      onlyif  => "grep -ve '^${name}\$' /etc/sunet-reinstall.keep"
   }
}
