
class sunet::telegraf::output {}

class sunet::telegraf::output::influxdb_v2 ($url = undef, $organization, $bucket) {
  $_url = $url ? {
      undef   => $title,
      default => $url
  }
  sunet::telegraf::plugin {'influxdb_v2': config => {url => $_url, organization => $organization, bucket => $bucket}}
}
