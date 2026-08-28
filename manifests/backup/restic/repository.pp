# @param url                    restic repository URL, e.g. 's3:s3.example.net/bucket'
#                               or a local path
# @param password               repository password. May be an eyaml-encrypted value
#                               nested in the Hiera hash.
# @param password_key           Hiera key holding the password, when it cannot be
#                               written inline. Defaults to 'restic_password_${name}'.
# @param env                    extra environment for restic, e.g. AWS_ACCESS_KEY_ID.
#                               Values may be eyaml-encrypted.
# @param env_hiera_keys         environment variable name => Hiera key holding its
#                               value. Merged over $env. For secrets that cannot be
#                               written inline.
# @param init                   create the repository when restic reports that it does
#                               not exist (exit status 10). A wrong password, missing
#                               credentials, an unreachable endpoint or a lock are all
#                               reported and left alone - only a genuinely absent
#                               repository is created. Set false where creating the
#                               repository, and for S3 possibly the bucket, should stay
#                               a manual and audited step: a typo in 'url' would
#                               otherwise create a new empty repository that backups
#                               then succeed into.
# @param prune                  schedule 'restic prune', which repacks the repository
#                               and drops data that no snapshot references. It cannot
#                               delete a snapshot: deciding what to keep belongs to the
#                               job, which tags its own snapshots and scopes a 'forget'
#                               to them. The repack lives here rather than in a job
#                               because it takes an exclusive lock on the whole
#                               repository, so jobs sharing one would race for it.
# @param prune_hour             hour for the prune job
# @param prune_minute           minute for the prune job. Defaults to a per-host
#                               random minute, to spread load across a fleet.
# @param prune_weekday          weekday for the prune job. Unset means daily.
# @param prune_max_age          scriptherder max_age for the prune job. Defaults to
#                               25h when it runs daily, 8d when it runs weekly.
# @param check                  schedule 'restic check'
# @param check_hour             hour for the check job
# @param check_minute           minute for the check job. Defaults to a per-host
#                               random minute.
# @param check_weekday          weekday for the check job. Unset means daily.
# @param check_read_data_subset 'restic check --read-data-subset', e.g. '5%'. Unset
#                               checks structure only, without reading pack files.
# @param ensure                 set to 'absent' to remove the repository
#                               configuration, its wrapper and its cron jobs. The
#                               repository data itself is never deleted.
define sunet::backup::restic::repository (
  String                   $url,
  Optional[String]         $password               = undef,
  Optional[String]         $password_key           = undef,
  Hash[String, String]     $env                    = {},
  Hash[String, String]     $env_hiera_keys         = {},
  Boolean                  $init                   = true,
  Boolean                  $prune                  = true,
  String                   $prune_hour             = '4',
  Optional[String]         $prune_minute           = undef,
  Optional[String]         $prune_weekday          = undef,
  Optional[String]         $prune_max_age          = undef,
  Boolean                  $check                  = true,
  String                   $check_hour             = '5',
  Optional[String]         $check_minute           = undef,
  Optional[String]         $check_weekday          = '6',
  Optional[String]         $check_read_data_subset = '5%',
  Enum['present','absent'] $ensure                 = 'present',
) {
  # Only the directory layout, never the main class - see the header of dirs.pp for
  # why that distinction matters.
  include sunet::backup::restic::dirs

  $safe_name = regsubst($title, '[^0-9A-Za-z._\-]', '_', 'G')

  $repos_dir     = $sunet::backup::restic::dirs::repos_dir
  $cache_dir     = $sunet::backup::restic::dirs::cache_dir
  $restic_bin    = $sunet::backup::restic::dirs::symlink
  $password_file = "${repos_dir}/${safe_name}.password"
  $env_file      = "${repos_dir}/${safe_name}.env"
  $init_stamp    = "${repos_dir}/${safe_name}.initialized"
  $init_script   = "${repos_dir}/${safe_name}-init.sh"
  $wrapper       = "/usr/local/bin/restic-${safe_name}"

  if $ensure == 'absent' {
    file { [$password_file, $env_file, $init_stamp, $init_script, $wrapper]:
      ensure => 'absent',
    }

    $_gone = [
      "restic-forget-${safe_name}",
      "restic-prune-${safe_name}",
      "restic-check-${safe_name}",
    ]

    sunet::scriptherder::cronjob { $_gone:
      ensure        => 'absent',
      cmd           => '/bin/true',
      purge_results => true,
    }
  } else {
    $_password = $password ? {
      undef   => safe_hiera(pick($password_key, "restic_password_${safe_name}")),
      default => $password,
    }

    if $_password == 'NOT_SET_IN_HIERA' {
      warning("No password for restic repository '${title}' - set 'password' in the \
restic_repositories entry, or the Hiera key '${pick($password_key, "restic_password_${safe_name}")}'. \
Skipping the repository entirely.")
    } else {
      # Environment values that live in their own Hiera keys. A key that is not set
      # is skipped rather than exported as the NOT_SET_IN_HIERA sentinel, which would
      # otherwise be handed to restic as a real credential.
      $hiera_env = $env_hiera_keys.reduce({}) |$memo, $pair| {
        $_value = safe_hiera($pair[1])
        if $_value == 'NOT_SET_IN_HIERA' {
          warning("Hiera key '${pair[1]}' for environment variable '${pair[0]}' of \
restic repository '${title}' is not set - not exporting it")
          $memo
        } else {
          $memo + { $pair[0] => $_value }
        }
      }
      # Quote in Puppet rather than in the templates, so the templates only ever
      # interpolate strings that are already safe to paste into a shell.
      $restic_env  = Hash(($env + $hiera_env).map |$name, $value| { [$name, shellquote($value)] })
      $quoted      = {
        'url'           => shellquote($url),
        'password_file' => shellquote($password_file),
        'cache_dir'     => shellquote($cache_dir),
        'env_file'      => shellquote($env_file),
        'restic_bin'    => shellquote($restic_bin),
        'wrapper'       => shellquote($wrapper),
      }

      file { $password_file:
        ensure    => 'file',
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
        content   => $_password,
        show_diff => false,  # avoid leaking the password into logs and reports
        require   => File[$repos_dir],
      }

      file { $env_file:
        ensure    => 'file',
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
        content   => template('sunet/backup/restic/repo-env.erb'),
        show_diff => false,  # may contain object store credentials
        require   => File[$repos_dir],
      }

      # Lets an operator run 'restic-<repo> snapshots' or
      # 'restic-<repo> restore latest --target /tmp/restore' without assembling the
      # environment by hand. Also what the cron jobs below invoke.
      file { $wrapper:
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0700',
        content => template('sunet/backup/restic/restic-wrapper.erb'),
      }

      if $init {
        # Decides whether to initialise from restic's exit status rather than from
        # "did it fail" - see the template. Kept as a script so that logic is
        # inspectable on the host instead of being an unreadable exec one-liner.
        file { $init_script:
          ensure  => 'file',
          owner   => 'root',
          group   => 'root',
          mode    => '0700',
          content => template('sunet/backup/restic/repo-init.erb.sh'),
          require => File[$repos_dir],
        }

        # The stamp file means the repository is probed over the network once, on the
        # first run, instead of on every Puppet run - while a genuinely
        # uninitialised repository on a fresh host still gets created. It also means a
        # repository that later disappears shows up as failing backups rather than
        # being silently recreated empty.
        exec { "restic_init_${safe_name}":
          command => $init_script,
          creates => $init_stamp,
          # File[$restic_bin] is declared by sunet::backup::restic. A repository
          # without that class is meaningless - there would be no binary to run - so
          # this reference deliberately fails the run rather than papering over it.
          require => [
            File[$init_script],
            File[$wrapper],
            File[$password_file],
            File[$env_file],
            File[$restic_bin],
          ],
        }
        -> file { $init_stamp:
          ensure  => 'file',
          owner   => 'root',
          group   => 'root',
          mode    => '0444',
          content => "restic repository ${url} initialized by puppet\n",
        }
      }

      if $prune {
        $_prune_max_age = pick($prune_max_age, $prune_weekday ? { undef => '25h', default => '8d' })

        # Repacking only. Deciding *which snapshots* to keep belongs to the job, which
        # tags its own snapshots and can therefore scope a 'forget' exactly - see
        # sunet::backup::restic::job. There is nothing to guard against here: 'restic
        # prune' drops data that no snapshot references and cannot delete a snapshot.
        sunet::scriptherder::cronjob { "restic-prune-${safe_name}":
          cmd           => "${wrapper} prune",
          hour          => $prune_hour,
          minute        => pick($prune_minute, String(fqdn_rand(60, "restic-prune-${safe_name}"))),
          weekday       => $prune_weekday,
          ok_criteria   => ['exit_status=0', "max_age=${_prune_max_age}"],
          warn_criteria => ['exit_status=1'],
        }
      }

      if $check {
        $check_args = $check_read_data_subset ? {
          undef   => 'check',
          default => "check --read-data-subset=${check_read_data_subset}",
        }

        $_check_max_age = $check_weekday ? { undef => '25h', default => '8d' }

        sunet::scriptherder::cronjob { "restic-check-${safe_name}":
          cmd           => "${wrapper} ${check_args}",
          hour          => $check_hour,
          minute        => pick($check_minute, String(fqdn_rand(60, "restic-check-${safe_name}"))),
          weekday       => $check_weekday,
          ok_criteria   => ['exit_status=0', "max_age=${_check_max_age}"],
          warn_criteria => ['exit_status=1'],
        }
      }
    }
  }
}
