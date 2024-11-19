# Kopia snapshots
class sunet::kopia::snapshots(
  Array[String] $jobs,
  String $environment,
  String $user = 'root',
  String $minute = '0',
  String $hour = '0',
  String $monthday = '*',
  String $weekday = '*',
){
  $dir = '/opt/kopia/repositories'
  $possible_jobs = lookup('kopia_backup_jobs', undef, undef, [])
  if $possible_jobs.empty {
    $project_mapping = lookup('project_mapping', undef, undef, [])
    $temp_jobs = $project_mapping.map |$key, $job| {
      if member($jobs, $key) {
        $config = $job[$environment]
        $primary = [
          {
            'name' => "${key}-${config['primary_project']}",
            'buckets' => [$config['primary_bucket']],
            'project' => $config['primary_project'],
            'mirror' => $config['mirror_project']
          }
        ]
        flatten($primary , map($config['assigned']) | $assigned | {
          {
            'name' => "${key}-${assigned['project']}",
            'buckets' => $assigned['buckets'],
            'project' => $assigned['project'],
            'mirror' => $assigned['mirror_project']
          }
        })
      } else {
        {}
      }
    }
  } else {
    $temp_jobs = $possible_jobs.map |$key, $job| {
      if member($jobs, $key) {
        $config = $job[$environment]
        map($config) | $assigned | {
          {
            'name' => "${key}-${assigned['project']}",
            'buckets' => $assigned['buckets'],
            'project' => $assigned['project'],
            'mirror' => $assigned['mirror']
          }
        }
      }
    }
  }
  $even_more_temp_jobs = flatten($temp_jobs)
  $backup_jobs = $even_more_temp_jobs.filter |$entry| { $entry != {}}
  $backup_jobs.each | $job| {
    $project = $job['project']
    $buckets = $job['buckets']
    $mirror = $job['mirror']
    $mirror_name = regsubst($mirror, '_', '-','G')
    $buckets.each | $bucket| {
      $repository_name = "${job['name']}-${mirror_name}-${bucket}"
      $password_name = "kopia_password_${mirror}"
      $password = lookup($password_name, undef, undef, 'NOT_SET_IN_HIERA')
      $repo_dir = "${dir}/${repository_name}"
      $config_file = "${repo_dir}/kopia.config"
      $snapshot_dir = "${repo_dir}/mnt"
      $remote_path = "${mirror}:${bucket}-kopia"
      if ($password != 'NOT_SET_IN_HIERA') {
        exec { "kopia_remote_dir_${repository_name}":
          command => "rclone mkdir ${remote_path}",
        }
        exec { "kopia_repository_dir_${repository_name}":
          command => "mkdir -p ${repo_dir}",
          unless  => "test -d ${repo_dir}",
        }
        -> sunet::kopia::repository { $repository_name:
          config_file     => $config_file,
          password        => $password,
          remote_path     => $remote_path,
          repository_name => $repository_name,
        }
        -> sunet::kopia::policy { $repository_name:
          config_file     => $config_file,
          remote_path     => $remote_path,
          repository_name => $repository_name,
          user_name       => 'root',
        }
        file { "kopia_cron_script_${repository_name}":
          ensure  => file,
          path    => "${repo_dir}/backup.sh",
          owner   => 'root',
          group   => 'root',
          mode    => '0700',
          content => template('sunet/kopia/backup.erb.sh'),
        }
        # Note: each script will sleep
        # an aditional random amount of time
        # between 0 and 1020 minutes before running
        -> sunet::scriptherder::cronjob { "kopia-snapshot-${repository_name}":
          cmd      => "${repo_dir}/backup.sh",
          user     => $user,
          minute   => $minute,
          hour     => $hour,
          monthday => $monthday,
          weekday  => $weekday,
        }
      } else {
        warning("Password for kopia repository ${repository_name} with ${password_name} not set in hiera")
      }
    }
  }
}
  # New style
  #kopia_backup_jobs:
  #  bth:
  #    prod:
  #       - buckets:
  #          - bth-data-001
  #          - bth-data-002
  #         project: sto4-1165
  #         mirror: sto3-1165
  #    test:
  #      - buckets:
  #          - bth-test-data-001
  #        project: sto4-1160
  #        mirror: sto3-1160
  # Drive style
  #project_mapping:
  #  bth:
  #    prod:
  #      mirror_project: sto3-57
  #      primary_bucket: primary-bth-drive.sunet.se
  #      primary_project: sto4-57
  #      assigned:
  #        - buckets:
  #            - bth-data-001
  #            - bth-data-002
  #          mirror_project: sto3-1165
  #          project: sto4-1165
  #    test:
  #      mirror_project: sto3-58
  #      primary_bucket: primary-bth-drive-test.sunet.se
  #      primary_project: sto4-58
  #      assigned:
  #        - buckets:
  #            - bth-test-data-001
  #          mirror_project: sto3-1160
  #          project: sto4-1160
