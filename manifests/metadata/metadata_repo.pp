# Wrapper to setup a metadata repo from GIT
class sunet::metadata::metadata_repo(
  String $hostname = undef,
  String $repo = undef,
  Optional[Boolean] $update_by_cron = false,
  Optional[Boolean] $signed_repo = false,
  Optional[String] $id_file = undef,
) {
  $host = $hostname ? {
    undef   => $title,
    default => $hostname
  }

  if ($id_file) {
    sunet::ssh_host_credential { "${title}-ssh-cred":
      hostname    => $host,
      id          => $id_file,
      manage_user => false
    }
  }

  if $signed_repo {
    $cache_dir = "/var/cache/metadata_${hostname}"
    vcsrepo { $cache_dir:
      ensure   => present,
      provider => git,
      source   => "git@${host}:${repo}"
    } -> package {
      ['make','gnupg2']: ensure => latest
    }
    if $update_by_cron {
      sunet::scriptherder::cronjob { 'verify_and_update':
        cmd           => "${cache_dir}/scripts/do-update.sh",
        minute        => '*/5',
        ok_criteria   => ['exit_status=0', 'max_age=15m'],
        warn_criteria => ['exit_status=0', 'max_age=1h'],
      }

      include sunet::nagios::nrpe_check_gpg_keys_bin

      sunet::nagios::nrpe_command { 'check_cosmos_keys':
        command_line => "/usr/lib/nagios/plugins/check_gpg_keys ${cache_dir}/keys",
      }
    }
  } else {
    vcsrepo { '/opt/metadata':
      ensure   => present,
      provider => git,
      source   => "git@${host}:${repo}"
    }
  }
}
