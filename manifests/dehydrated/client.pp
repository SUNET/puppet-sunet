# If this class is used, only a single domain can be set up because puppet won't allow
# re-instantiating classes with different $domain
class sunet::dehydrated::client(
  String  $domain,
  String  $server='acme-c.sunet.se',
  String  $user='root',
  Boolean $ssl_links=false,
  Boolean $check_cert=true,
  String  $check_cert_port='443',
  Boolean $manage_ssh_key=true,
  Optional[String] $ssh_id=undef,
  Boolean $single_domain=true,
) {
  sunet::dehydrated::client_define { "domain_${domain}":
    domain          => $domain,
    server          => $server,
    user            => $user,
    ssl_links       => $ssl_links,
    check_cert      => $check_cert,
    check_cert_port => $check_cert_port,
    manage_ssh_key  => $manage_ssh_key,
    ssh_id          => $ssh_id,
    single_domain   => $single_domain,
  }
}
