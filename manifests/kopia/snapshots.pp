# Kopia snapshots
define sunet::kopia::snapshots(
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
    $backup_jobs = $project_mapping.map |$key, $job| {
      if member($jobs, $key) {
        $config = $job[$environment]
        $temp = map($config['assigned']) | $assigned | {
          {
            'name' => "${key}-${assigned['primary_project']}",
            'buckets' => $assigned['buckets'],
            'project' => $assigned['primary_project'],
            'mirror' => $assigned['mirror_project']
          }
        }
        flatten($temp, [
          {
            'name' => "${key}-primary",
            'buckets' => [$config['primary_bucket']],
            'project' => $config['primary_project'],
            'mirror' => $config['mirror_project']
          }
        ])
      }
    }
  } else {
    $backup_jobs = $possible_jobs.map |$key, $job| {
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
  $backup_jobs.each | $job| {
    $project = $job['project']
    $buckets = $job['buckets']
    $mirror = $job['mirror']
    $buckets.each | $bucket| {
      $repository_name = "${job['name']}-${mirror}-${bucket}"
      $repo_dir = "${dir}/${repository_name}"
      $config_file = "${repo_dir}/kopia.config"
      $snapshot_dir = "${repo_dir}/mnt"
      $remote_path = "${mirror}:${bucket}"
      $policy = sunet::kopia::policy { $repository_name:
        repository_name => $repository_name,
        user_name       => 'root',
      }
      $repo = sunet::kopia::repository { $repository_name:
        repository  => $repository_name,
        remote_path => $remote_path,
        config_file => $config_file,
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
        command  => "${repo_dir}/backup.sh",
        user     => $user,
        minute   => $minute,
        hour     => $hour,
        monthday => $monthday,
        weekday  => $weekday,
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
