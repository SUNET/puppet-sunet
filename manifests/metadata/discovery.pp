# Set up a discovery service using docker
class sunet::metadata::discovery(
    Array[Enum['mdq', 'discovery']] $features = [],
    Boolean $ds_tls = lookup('ds_tls', Boolean, undef, true),
    Optional[String] $base_url = lookup('base_url', Optional[String], undef, undef),
    Optional[String] $context = lookup('context', Optional[String], undef, undef),
    Optional[String] $domain = lookup('domain', Optional[String], undef, undef),
    Optional[String] $mdq_search_url = lookup('mdq_search_url', Optional[String], undef, undef),
    Optional[String] $src = lookup('src', Optional[String], undef, undef),
    Optional[String] $src_trust = lookup('src_trust', Optional[String], undef, undef),
    Optional[String] $whitelist = lookup('whitelist', Optional[String], undef, undef),
    String $ds_image = lookup('ds_image', String, undef, 'docker.sunet.se/thiss-js'),
    String $ds_version = lookup('ds_version', String, undef, 'latest'),
    String $mdq_image = lookup('mdq_image', String, undef, 'docker.sunet.se/thiss-mdq'),
    String $mdq_version = lookup('mdq_version', String, undef, 'latest'),
) {

  $mdq = 'mdq' in $features
  $ds = 'discovery' in $features

  if ($mdq) {

    if $src  == undef { fail('src is required when mdq feature is enabled')  }
    if $src_trust == undef { fail('src_trust is required when mdq feature is enabled') }

    file { '/opt/discovery/metadata':
      ensure =>  'directory'
    }

    -> file { '/usr/local/bin/get_ds_metadata.sh':
        content => template('sunet/metadata/get_ds_metadata.sh.erb'),
        owner   => root,
        group   => root,
        mode    => '0755'
    }
    -> sunet::scriptherder::cronjob { "${name}_fetch_metadata":
      cmd           => '/usr/local/bin/get_metadata.sh',
      minute        => '*/5',
      ok_criteria   => ['exit_status=0','max_age=48h'],
      warn_criteria => ['exit_status=1','max_age=50h'],
    }

    exec { 'run_get_ds_metadata':
      command     => '/usr/local/bin/get_ds_metadata.sh',
      subscribe   => File['/usr/local/bin/get_ds_metadata.sh'],
      refreshonly => true,
    }

    if (!$ds) {
      sunet::nftables::allow { 'allow-incoming-mdq':
        from => 'any',
        port => '80',
      }
    }
  }

  if ($ds) {

    if $base_url       == undef { fail('base_url is required when ds feature is enabled')       }
    if $context        == undef { fail('context is required when ds feature is enabled')        }
    if $domain         == undef { fail('domain is required when ds feature is enabled')         }
    if $whitelist      == undef { fail('whitelist is required when ds feature is enabled') }

    if ($ds_tls) {
      $hook_dir='/etc/letsencrypt/renewal-hooks/deploy'
      ensure_resource('file', '/etc/letsencrypt', { 'ensure' => 'directory' })
      ensure_resource('file', '/etc/letsencrypt/renewal-hooks', { 'ensure' => 'directory' })
      ensure_resource('file', $hook_dir, { 'ensure' => 'directory' })
      file { "${hook_dir}/discovery-renewal-hook":
          content => file('sunet/metadata/discovery-renewal-hook'),
          owner   => root,
          group   => root,
          mode    => '0755'
      }
    }

    $final_mdq_search_url = $mdq_search_url ? {
      undef   => "${base_url}/entities",
      default => $mdq_search_url,
    }
    sunet::snippets::somaxconn { 'ds_nginx': maxconn => 4096 }

    $ds_port = $ds_tls ? {
      true   => '443',
      false  => '80'
    }

    sunet::nftables::allow { 'allow-incoming-ds':
      from => 'any',
      port => $ds_port,
    }
  }

  sunet::docker_compose { 'mdq_publisher':
    content          => template('sunet/metadata/docker-compose-discovery.yml.erb'),
    service_name     => 'discovery',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Thiss.io Discovery/MDQ service',
  }
}
