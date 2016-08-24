define sunet::metadata($url=undef,
                       $filename=undef) {
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
   cron {$fetch:
      command => "/usr/bin/wget ${n_c_s} -q ${url} -N -O ${local}.tmp && chmod 0644 ${local}.tmp && test -s ${local}.tmp && mv ${local}.tmp ${local}",
      user    => 'root',
      minute  => '*/5'
   }
}
