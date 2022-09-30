function sunet::microk8s::set_secret(
  String namespace,
  String name,
  String key,
  String value,
  Bool, update = true,
) >> Bool {
  exec { 'microk8s_secret_exists':
    if $update {
      $only_if = ['/bin/true']
    } else {
      $only_if = ["! microk8s kubectl get secrets -n ${namespace} ${name}"]
    }
    command => "microk8s kubectl -n ${namespace} create secret generic ${name} --from-literal=${key}=${value} --dry-run=client -o yaml | microk8s kubectl apply -f -",
    onlyif => $only_if,
    provider => posix, 
  }
}
