# Run tunnelbana in docker-compose.
#
# The main deployment input is the Hiera hash `tunnelbana_proxy_conf`, which is
# rendered to `$config_dir/proxy.toml` and mounted into the container as
# `/app/config/proxy.toml`.
#
# `tunnelbana_additional_tomls` is a hash from file name (without `.toml`) to a
# hash rendered as TOML. Each entry is written to `$config_dir/<name>.toml` and
# mounted into the container as `/app/config/<name>.toml`. Attribute mapping
# (e.g. `custom_attributes`) is deployment policy, just like SATOSA's generated
# `internal_attributes.yaml`, so this module does not ship a fallback map but
# the upstream container does.
#
# Additional Hiera-backed files can be supplied as maps from Hiera key name to
# target path:
# - `tunnelbana_config` for extra config/TOML files.
# - `tunnelbana_files` for non-secret certs or metadata.
# - `tunnelbana_secret_files` for private keys and other sensitive files.
#   These values are Hiera secret keys, normally from per-host or shared eyaml;
#   only the key names and destination paths should be in ordinary git data.
#
# Every `frontend`/`backend` of type `saml2` in `tunnelbana_proxy_conf` gets a
# key and certificate in `$keys_dir` named `<frontend|backend>-<name>.key` and
# `.pem` (name lowercased, non-alphanumerics replaced by `_`). The TOML must
# point at them, e.g. `../keys/backend-saml2.key`, using `sp_key_path`/
# `sp_cert_path` for backends and `idp_key_path`/`idp_cert_path` for frontends.
# A key is taken from Hiera `tunnelbana_<end>_<name>_key` (and optionally
# `tunnelbana_<end>_<name>_cert`) when set, otherwise a self-signed pair is
# generated; see `sunet::tunnelbana::saml2_keypair`.
class sunet::tunnelbana(
  String                  $image            = 'docker.sunet.se/tunnelbana',
  String                  $tunnelbana_tag   = '0.5.0',
  String                  $config_dir       = '/opt/tunnelbana/config',
  String                  $keys_dir         = '/opt/tunnelbana/keys',
  String                  $metadata_dir     = '/opt/tunnelbana/metadata',
  Integer                 $expose_port      = 443,
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

  ensure_resource('file', '/opt/tunnelbana', {
      ensure => directory,
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
  })

  include sunet::packages::certbot
  file { '/etc/letsencrypt/renewal-hooks/deploy/tunnelbana-hook':
    ensure  => file,
    mode    => '0755',
    content => file('sunet/tunnelbana/tunnelbana-renewal-hook'),
    require => File['/etc/letsencrypt/renewal-hooks/deploy'],
    before  => Class['sunet::certbot::acmed'],
  }

  # The production image runs as the unprivileged `tunnelbana` user with UID
  # 10001. Numeric ownership keeps the files readable inside the container even
  # when the host does not have a matching passwd/group entry.
  file { [$config_dir, $keys_dir, $metadata_dir]:
    ensure  => directory,
    owner   => '10001',
    group   => '10001',
    mode    => '0750',
    require => File['/opt/tunnelbana'],
    before  => Sunet::Docker_compose['tunnelbana_compose'],
  }

  $proxy_conf = lookup('tunnelbana_proxy_conf', undef, undef, {})
  if empty($proxy_conf) {
    fail('tunnelbana: tunnelbana_proxy_conf is not set')
  }

  file { "${config_dir}/proxy.toml":
    ensure  => file,
    owner   => '10001',
    group   => '10001',
    mode    => '0440',
    content => stdlib::to_toml($proxy_conf),
    require => File[$config_dir],
    notify  => $service_to_notify,
    before  => Sunet::Docker_compose['tunnelbana_compose'],
  }

  ['frontend', 'backend'].each |$end| {
    $saml2_ends = pick($proxy_conf[$end], []).filter |$e| { $e['type'] == 'saml2' }
    $saml2_ends.each |$e| {
      if $e['name'] == undef {
        fail("tunnelbana: ${end} of type saml2 requires a name")
      }
      $slug = regsubst(downcase($e['name']), '[^0-9a-z]', '_', 'G')
      sunet::tunnelbana::saml2_keypair { "${end}-${slug}":
        end               => $end,
        slug              => $slug,
        keys_dir          => $keys_dir,
        service_to_notify => $service_to_notify,
        require           => File[$keys_dir],
        before            => Sunet::Docker_compose['tunnelbana_compose'],
      }
    }
  }

  $additional_tomls = lookup('tunnelbana_additional_tomls', Hash[Pattern[/\A[0-9A-Za-z_-]+\z/], Hash], undef, {})
  $additional_tomls.each |$name, $toml_conf| {
    file { "${config_dir}/${name}.toml":
      ensure    => file,
      owner     => '10001',
      group     => '10001',
      mode      => '0440',
      content   => stdlib::to_toml($toml_conf),
      show_diff => false,
      require   => File[$config_dir],
      notify    => $service_to_notify,
      before    => Sunet::Docker_compose['tunnelbana_compose'],
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

  sunet::docker_compose { 'tunnelbana_compose':
    content            => template('sunet/tunnelbana/docker-compose.yml.erb'),
    service_name       => 'tunnelbana',
    compose_dir        => '/opt',
    service_dir_layout => true,
    description        => 'Tunnelbana',
  }

  sunet::nftables::allow { 'tunnelbana_https':
    from => 'any',
    port => $expose_port,
  }
}
