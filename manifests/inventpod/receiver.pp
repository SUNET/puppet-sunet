# Deploy the rootless receiver and its HTTPS vhost from a Cosmos host rule.
# The image profile, Podman secret name and listener settings use sunet::inventpod Hiera data.
class sunet::inventpod::receiver (
  Pattern[/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+\z/] $vhost,
) {
  class { 'sunet::inventpod':
    hostname => $vhost,
  }
}
