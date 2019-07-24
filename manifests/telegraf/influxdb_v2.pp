class sunet::telegraf::influxdb_v2($url=undef,$bucket=undef,$organization=undef) {
   $token = hiera('influxdb_v2_token');
   $_url      = $title ? {
      undef   => fail('influxdb_v2 needs url parameter'),
      default => $url
   };
   $_bucket   = $bucket ? {
      undef   => fail('influxdb_v2 needs bucket parameter'),
      default => $bucket
   };
   $_org      = $organization ? {
      undef   => fail('influxdb_v2 needs url parameter'),
      default => $organization
   };
   if $token == 'NOT_SET_IN_HIERA' {
      fail('influxdb_v2 token nees to be set in hiera');
   }
   file {'/etc/telegraf/telegraf.d/influxdb_v2.conf':
      ensure  => file,
      content => template('sunet/telegraf/plugins/influxdb_v2.conf'),
      notify  => Service['telegraf']
   }
}
