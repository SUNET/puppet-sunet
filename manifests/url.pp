define sunet::url($url=undef,
                  $filename=undef,
                  $mode=0755,
                  $check_certificate=true) {
   $local = $filename ? {
      undef   => $name,
      default => $local
   }
   $n_c_s = $check_certificate ? {
      true    => '',
      false   => '--no-check-certificate'
   }
   $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G')
   $fetch = "fetch_${safe_name}"
   exec {$fetch: 
      command => "/usr/bin/wget ${n_c_s} -q ${url} -N -O ${local}",
      creates => $local
   }
   file {$local:
      mode    => $mode,
      require => Exec [$fetch]
   }
}
