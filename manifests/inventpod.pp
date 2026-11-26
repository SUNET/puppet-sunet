# The public listener requires a site-reviewed profile for a corrected receiver.
class sunet::inventpod (
  Pattern[/\A[a-z0-9][a-z0-9.-]*\z/] $hostname,
  Pattern[/\A[a-zA-Z0-9_.-]+\z/] $admin_secret,
  Pattern[/\A[a-z][a-z0-9_]*\/[a-z][a-z0-9_]*\/[a-z0-9_-]+\z/] $receiver_profile = 'sunet/invent_receiver/2',
  Pattern[/\A[a-z][a-z0-9_]*\/[a-z][a-z0-9_]*\/[a-z0-9_-]+\z/] $caddy_profile = 'sunet/caddy/1',
  Boolean $public_https = false,
  Optional[Pattern[/\A[a-z][a-z0-9-]*\z/]] $site_redirect_service = undef,
  Optional[String] $approved_public_profile = undef,
  Stdlib::IP::Address::V4::Nosubnet $listen_address = '127.0.0.1',
  Pattern[/\A[a-zA-Z0-9_.-]+\z/] $interface = 'eth0',
  Integer[1024,65535] $https_port = 8443,
  Integer[1024,65535] $receiver_port = 18000,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $receiver_proxy_address = undef,
  String $receiver_level = 's0:c100,c101',
  String $caddy_level = 's0:c104,c105',
  String $report_level = 's0:c100',
  Pattern[/\A\/var\/lib\/sunet-podman2\/data(?:\/[a-zA-Z0-9_-]+)*\z/] $data_root = '/var/lib/sunet-podman2/data',
  Optional[String] $ni_key = undef,
  Optional[Stdlib::IP::Address::V4::Nosubnet] $ni_ip = undef,
  Hash[String, Struct[{backend => String[1], port => Integer[1,65535]}]] $additional_vhosts = {},
) {
  include sunet::podman2
  if $public_https {
    if $receiver_profile in ['sunet/invent_receiver/1', 'sunet/invent_receiver/2'] or $approved_public_profile != $receiver_profile or
       $listen_address == '0.0.0.0' or $listen_address =~ /\A127\./ {
      fail('Public HTTPS requires an approved corrected receiver profile and site address')
    }
    [$provider, $image, $revision] = split($receiver_profile, '/')
    $approved = parseyaml(file("${provider}/podman2/images/${image}/${revision}/profile.yaml"))
    if $approved['reviewed_files']['/app/main.py']['sha256'] !~ /\A[0-9a-f]{64}\z/ {
      fail('Public receiver approval must cover the bytes of the authorization implementation')
    }
    if $site_redirect_service {
      if $facts['sunet_nftables_enabled'] == 'yes' {
        fail('Assign the HTTPS redirect to only one firewall manager')
      }
      Service[$site_redirect_service] -> Exec['qualify rootless podman2 releases']
    } elsif $facts['sunet_nftables_enabled'] == 'yes' {
      include sunet::nftables::init
      sunet::nftables::rule { 'podman2_https_redirect':
        group => 'podman2_https',
        rule  => "add table ip podman2_https\nadd chain ip podman2_https prerouting { type nat hook prerouting priority dstnat; }\nadd rule ip podman2_https prerouting iifname \"${interface}\" ip daddr ${listen_address} tcp dport 443 redirect to :${https_port}\nadd rule inet filter input iifname \"${interface}\" ip daddr ${listen_address} ct original proto-dst 443 ct status dnat tcp dport ${https_port} accept",
      }
      Service['nftables'] -> Exec['qualify rootless podman2 releases']
    } else {
      fail('Public HTTPS requires a managed nftables redirect')
    }
  } elsif $listen_address != '127.0.0.1' {
    fail('The private pilot listener requires loopback')
  }
  if ($ni_key == undef) != ($ni_ip == undef) {
    fail('Supply the NI public key and address together')
  }
  $data = $data_root
  if $ni_key {
    if $ni_key !~ /\A[A-Za-z0-9+\/=]+\z/ {
      fail('Invalid NI ed25519 public key')
    }
    ensure_packages(['rsync', 'acl'])
    group { 'invent-ni': ensure => present, system => true }
    user { 'invent-ni':
      ensure => present, system => true, gid => 'invent-ni', groups => [],
      membership => inclusive, home => '/home/invent-ni', managehome => true,
      shell => '/bin/bash', password => '!!',
    }
    $options = "restrict,from=\"${ni_ip}\",command=\"/usr/share/doc/rsync/support/rrsync -ro ${data}/reports\""
    sunet::ssh_keys { 'podman2-ni-rrsync':
      config   => { 'invent-ni' => ['ni-reports'] },
      require  => User['invent-ni'],
      database => { 'ni-reports' => {'key' => $ni_key, 'type' => 'ssh-ed25519', 'options' => $options} },
      order    => '210',
    }
    ['hosts','images','network'].each |$endpoint| {
      $directory = "${data}/reports/${endpoint}"
      exec { "NI access to ${endpoint} reports":
        command => "/usr/bin/setfacl -m u:invent-ni:r-x,d:u:invent-ni:r-x ${directory}",
        unless  => "/usr/bin/getfacl -cp ${directory} | /usr/bin/grep -Fxq default:user:invent-ni:r-x && /usr/bin/getfacl -cp ${directory} | /usr/bin/grep -Fxq user:invent-ni:r-x",
        require => [User['invent-ni'], Package['acl'], Exec['qualify rootless podman2 releases']],
      }
    }
    if $facts['sunet_nftables_enabled'] == 'yes' {
      include sunet::nftables::init
      sunet::nftables::rule { 'podman2_ni_ssh':
        rule => "add rule inet filter input iifname \"${interface}\" ip saddr ${ni_ip} tcp dport 22 accept",
      }
    }
  }
  $receiver_bindings = {
    'db' => { 'path' => "${data}/invent/db", 'level' => $receiver_level },
    'hosts' => { 'path' => "${data}/reports/hosts", 'level' => $report_level },
    'images' => { 'path' => "${data}/reports/images", 'level' => $receiver_level },
    'network' => { 'path' => "${data}/reports/network", 'level' => $receiver_level },
  }
  sunet::podman2::container { 'invent-receiver':
    profile  => $receiver_profile,
    level    => $receiver_level,
    quadlet  => template('sunet/podman2/receiver.container.erb'),
    bindings => $receiver_bindings,
  }
  $issuer = $public_https ? {
    true    => "  cert_issuer acme {\n    email noc@sunet.se\n    disable_http_challenge\n  }\n",
    default => '',
  }
  concat { '/etc/sunet-podman2/Caddyfile':
    owner => 'root', mode => '0644',
    before => Exec['qualify rootless podman2 releases'],
  }
  concat::fragment { 'podman2 caddy settings':
    target  => '/etc/sunet-podman2/Caddyfile',
    order   => '00',
    content => "{\n  auto_https disable_redirects\n  servers {\n    protocols h1 h2\n  }\n  https_port ${https_port}\n${issuer}}\n",
  }
  sunet::inventpod::vhost { $hostname: backend => '169.254.1.3', port => $receiver_port }
  $additional_vhosts.each |$host,$target| { sunet::inventpod::vhost { $host: * => $target } }
  sunet::podman2::container { 'invent-caddy':
    profile  => $caddy_profile,
    level    => $caddy_level,
    after_units => ['invent-receiver'],
    quadlet  => template('sunet/podman2/caddy.container.erb'),
    bindings => {
      'conf' => { 'path' => "${data}/caddy/conf", 'level' => $caddy_level, 'caddyfile' => true },
      'config' => { 'path' => "${data}/caddy/config", 'level' => $caddy_level },
      'data' => { 'path' => $public_https ? { true => "${data}/caddy/public-data", false => "${data}/caddy/data" }, 'level' => $caddy_level },
    },
  }
  $probe_target = $public_https ? {
    true  => "--connect-to ${hostname}:443:${listen_address}:${https_port} https://${hostname}/openapi.json",
    false => "http://127.0.0.1:${receiver_port}/openapi.json",
  }
  file { '/usr/local/libexec/sunet-podman2/check-invent':
    owner => 'root', mode => '0755',
    content => "#!/bin/sh\nexec /usr/bin/curl --fail --silent --show-error --max-time 8 -o /dev/null ${probe_target}\n",
  }
  sunet::nagios::nrpe_command { 'check_inventpod':
    command_line => '/usr/local/libexec/sunet-podman2/check-invent',
  }
}
