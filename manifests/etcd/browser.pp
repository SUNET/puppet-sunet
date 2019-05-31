# etcd browser
class sunet::etcd::browser(
  Array $docker_depends = ["etcd_${name}"],
  Strng $listen_on = '127.0.0.1',
) {
  sunet::docker_run { "etcd-browser-${name}":
    image   => 'docker.sunet.se/etcd-browser',
    ports   => [ "${listen_on}:8000:8000" ],
    depends => $docker_depends,
  }
}
