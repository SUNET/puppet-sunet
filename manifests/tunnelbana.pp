# Run tunnelbana in docker-compose.
#
# The main deployment input is `tunnelbana_proxy_toml`, which is written under
# `$config_dir` using `$config_file` and mounted into the container as
# `/app/config/$config_file`. `tunnelbana_state_key` is written to an env file
# as `TUNNELBANA_STATE_KEY` so the TOML can use `${TUNNELBANA_STATE_KEY}`
# without storing the secret in the compose file.
#
# `tunnelbana_attributes_toml` must be provided by each deployment. Attribute
# mapping is deployment policy, just like SATOSA's generated
# `internal_attributes.yaml`, so this module does not ship a fallback map.
#
# Additional Hiera-backed files can be supplied as maps from Hiera key name to
# target path:
# - `tunnelbana_config` for extra config/TOML files.
# - `tunnelbana_files` for non-secret certs or metadata.
# - `tunnelbana_secret_files` for private keys and other sensitive files.
#   These values are Hiera secret keys, normally from per-host or shared eyaml;
#   only the key names and destination paths should be in ordinary git data.
class sunet::tunnelbana(
  String                  $image            = 'docker.sunet.se/tunnelbana',
  String                  $tunnelbana_tag   = '0.2.0',
  String                  $config_dir       = '/etc/tunnelbana/config',
  String                  $keys_dir         = '/etc/tunnelbana/keys',
  String                  $metadata_dir     = '/etc/tunnelbana/metadata',
  Integer[1, 65535]       $host_port        = 8088,
  Optional[Array[String]] $ports            = undef,
  String                  $tunnelbana_bind  = '0.0.0.0:8080',
  String                  $config_file      = 'proxy.toml',
  Array[String]           $environment      = [],
  Optional[String]        $proxy_toml       = lookup('tunnelbana_proxy_toml', Optional[String], undef, undef),
  String                  $attributes_toml  = lookup('tunnelbana_attributes_toml', String),
  Optional[String]        $state_key        = lookup('tunnelbana_state_key', Optional[String], undef, undef),
  Hash[String, String]    $config_files     = lookup('tunnelbana_config', Hash[String, String], undef, {}),
  Hash[String, String]    $files            = lookup('tunnelbana_files', Hash[String, String], undef, {}),
  Hash[String, String]    $secret_files     = lookup('tunnelbana_secret_files', Hash[String, String], undef, {}),
) {
  # Only notify the service if it already exists on disk. This mirrors
  # `sunet::satosa` and avoids restart attempts during first install.
  if ($::facts['sunet_tunnelbana_exists'] == 'yes') {
    $service_to_notify = Service['sunet-tunnelbana']
  }
  else
  {
    $service_to_notify = undef
  }

  $env_file = '/etc/tunnelbana/tunnelbana.env'

  # Tunnelbana serves plain HTTP. Bind the host port to loopback by default so a
  # local reverse proxy, such as Caddy, can terminate TLS and expose public 443.
  $port_bindings = $ports ? {
    undef   => ["127.0.0.1:${host_port}:8080"],
    default => $ports,
  }

  ensure_resource('file', '/etc/tunnelbana', {
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
  })

  # The production image runs as the unprivileged `tunnelbana` user with UID
  # 10001. Numeric ownership keeps the files readable inside the container even
  # when the host does not have a matching passwd/group entry.
  file { [$config_dir, $keys_dir, $metadata_dir]:
    ensure  => directory,
    owner   => '10001',
    group   => '10001',
    mode    => '0750',
    require => File['/etc/tunnelbana'],
    before  => Sunet::Docker_compose['tunnelbana_compose'],
  }

  if $proxy_toml != undef {
    file { "${config_dir}/${config_file}":
      ensure    => file,
      owner     => '10001',
      group     => '10001',
      mode      => '0440',
      content   => "${proxy_toml}\n",
      show_diff => false,
      require   => File[$config_dir],
      notify    => $service_to_notify,
      before    => Sunet::Docker_compose['tunnelbana_compose'],
    }
  } else {
    warning("tunnelbana_proxy_toml is not set; ${config_dir}/${config_file} will not be managed")
  }

  file { "${config_dir}/attributes.toml":
    ensure    => file,
    owner     => '10001',
    group     => '10001',
    mode      => '0440',
    content   => "${attributes_toml}\n",
    show_diff => false,
    require   => File[$config_dir],
    notify    => $service_to_notify,
    before    => Sunet::Docker_compose['tunnelbana_compose'],
  }

  # Extra config/public/secret maps let deployments keep protocol-specific keys,
  # certs and metadata in Hiera without adding a new class parameter each time.
  # Like `sunet::satosa`, private key material is written through
  # `sunet::snippets::secret_file` from Hiera and is never passed through the
  # compose template or committed as a plaintext cosmos file. Tunnelbana does
  # not generate fallback keys here: each deployment decides the filename and key
  # algorithm in `proxy.toml`.
  $config_files.each |$hiera_key, $path| {
    $config_content = lookup($hiera_key, Optional[String], undef, undef)
    if $config_content != undef {
      file { $path:
        ensure    => file,
        owner     => '10001',
        group     => '10001',
        mode      => '0440',
        content   => "${config_content}\n",
        show_diff => false,
        require   => [File[$config_dir], File[$keys_dir], File[$metadata_dir]],
        notify    => $service_to_notify,
        before    => Sunet::Docker_compose['tunnelbana_compose'],
      }
    }
  }

  $files.each |$hiera_key, $path| {
    $file_content = lookup($hiera_key, Optional[String], undef, undef)
    if $file_content != undef {
      file { $path:
        ensure  => file,
        owner   => '10001',
        group   => '10001',
        mode    => '0440',
        content => $file_content,
        require => [File[$config_dir], File[$keys_dir], File[$metadata_dir]],
        notify  => $service_to_notify,
        before  => Sunet::Docker_compose['tunnelbana_compose'],
      }
    }
  }

  $secret_files.each |$hiera_key, $path| {
    if lookup($hiera_key, undef, undef, undef) != undef {
      sunet::snippets::secret_file { $path:
        hiera_key => $hiera_key,
        owner     => '10001',
        group     => '10001',
        mode      => '0400',
        require   => [File[$config_dir], File[$keys_dir], File[$metadata_dir]],
        notify    => $service_to_notify,
        before    => Sunet::Docker_compose['tunnelbana_compose'],
      }
    }
  }

  $env_content = $state_key ? {
    undef   => '',
    default => "TUNNELBANA_STATE_KEY=${state_key}\n",
  }

  file { $env_file:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0400',
    content   => $env_content,
    show_diff => false,
    require   => File['/etc/tunnelbana'],
    notify    => $service_to_notify,
    before    => Sunet::Docker_compose['tunnelbana_compose'],
  }

  sunet::docker_compose { 'tunnelbana_compose':
    content          => template('sunet/tunnelbana/docker-compose.yml.erb'),
    service_name     => 'tunnelbana',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Tunnelbana',
  }
}
