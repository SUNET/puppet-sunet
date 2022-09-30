function sunet::microk8s::node::set_secret(
  String namespace,
  String name,
  String key,
  String value,
  Bool, update = true,
) >> Bool {
  if $update {
    $only_if = ['/bin/true']
  } else {
    $only_if = ["! microk8s kubectl get secrets -n ${namespace} ${name}"]
  }
  exec { 'microk8s_secret_exists':
    command  => "microk8s kubectl -n ${namespace} create secret generic ${name} --from-literal=${key}=${value} --dry-run=client -o yaml " +
    '| microk8s kubectl apply -f -',
    onlyif   => $only_if,
    provider => posix,
  }
}
