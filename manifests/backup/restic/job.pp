# @param paths              paths to back up. Required.
# @param repository         name of the sunet::backup::restic::repository to back up
#                           to. Required.
# @param exclude            'restic backup --exclude' patterns
# @param exclude_if_present 'restic backup --exclude-if-present' filenames, e.g.
#                           '.nobackup'
# @param exclude_caches     skip directories tagged as caches per the Cache Directory
#                           Tagging Standard
# @param one_file_system    do not cross filesystem boundaries
# @param tags               extra snapshot tags. The job name is always a tag.
# @param extra_args         further arguments appended to 'restic backup'
# @param pre_hooks          scripts to run before the backup, as a hash of filename to
#                           either { source => } or { template => } - exactly one of the
#                           two. The key becomes the filename under <job dir>/pre.d and
#                           therefore the execution order, so name them '10-dump',
#                           '20-something'. The first hook that fails aborts the backup.
#                           A template is rendered in this define's scope, so it can read
#                           the job's own variables.
# @param post_hooks         scripts to run after the backup, same shape as pre_hooks. All
#                           of them run, even if the backup or an earlier hook failed.
# @param keep_last          'restic forget --keep-last' for this job's snapshots
# @param keep_hourly        'restic forget --keep-hourly' for this job's snapshots
# @param keep_daily         'restic forget --keep-daily' for this job's snapshots
# @param keep_weekly        'restic forget --keep-weekly' for this job's snapshots
# @param keep_monthly       'restic forget --keep-monthly' for this job's snapshots
# @param keep_yearly        'restic forget --keep-yearly' for this job's snapshots
# @param special            cron shorthand schedule, e.g. 'daily'
# @param hour               cron hour
# @param minute             cron minute
# @param weekday            cron weekday
# @param monthday           cron monthday
# @param random_sleep       seconds of random delay before starting, to spread load
#                           across a fleet
# @param max_age            scriptherder max_age: how stale a successful run may get
#                           before monitoring complains
# @param ensure             set to 'absent' to remove the job, its hooks and its cron
#                           entry
define sunet::backup::restic::job (
  Array[String[1]]         $paths,
  String                   $repository,
  Array[String]            $exclude            = [],
  Array[String]            $exclude_if_present = [],
  Boolean                  $exclude_caches     = true,
  Boolean                  $one_file_system    = false,
  Array[String]            $tags               = [],
  Array[String]            $extra_args         = [],
  Hash[String[1], Struct[{Optional['source'] => String[1], Optional['template'] => String[1]}]] $pre_hooks = {},
  Hash[String[1], Struct[{Optional['source'] => String[1], Optional['template'] => String[1]}]] $post_hooks = {},
  Optional[Integer]        $keep_last          = undef,
  Optional[Integer]        $keep_hourly        = undef,
  Optional[Integer]        $keep_daily         = undef,
  Optional[Integer]        $keep_weekly        = undef,
  Optional[Integer]        $keep_monthly       = undef,
  Optional[Integer]        $keep_yearly        = undef,
  Optional[String]         $special            = 'daily',
  Optional[String]         $hour               = undef,
  Optional[String]         $minute             = undef,
  Optional[String]         $weekday            = undef,
  Optional[String]         $monthday           = undef,
  Integer                  $random_sleep       = 1800,
  String                   $max_age            = '25h',
  Enum['present','absent'] $ensure             = 'present',
) {
  # Only the directory layout, never the main class - see the header of dirs.pp for
  # why that distinction matters.
  include sunet::backup::restic::dirs

  $safe_name = regsubst($title, '[^0-9A-Za-z._\-]', '_', 'G')
  $job_dir   = "${sunet::backup::restic::dirs::jobs_dir}/${safe_name}"
  $script    = "${job_dir}/backup.sh"
  $pre_dir   = "${job_dir}/pre.d"
  $post_dir  = "${job_dir}/post.d"

  if $ensure == 'absent' {
    file { $job_dir:
      ensure => 'absent',
      force  => true,
    }

    sunet::scriptherder::cronjob { "restic-backup-${safe_name}":
      ensure        => 'absent',
      cmd           => '/bin/true',
      purge_results => true,
    }
  } else {
    $safe_repository = regsubst($repository, '[^0-9A-Za-z._\-]', '_', 'G')
    $env_file        = "${sunet::backup::restic::dirs::repos_dir}/${safe_repository}.env"
    $restic_bin      = $sunet::backup::restic::dirs::symlink

    # The job name is always a tag, so snapshots can be attributed to the job that
    # created them without the caller having to remember to say so - and so that
    # job-scoped retention below has a reliable selector.
    $restic_tags = unique([$safe_name] + $tags)

    # Retention, run inside backup.sh right after a successful backup. This is the only
    # place retention is expressed: the repository just repacks.
    #
    # '--group-by' is disabled rather than left at its default of host,paths. With
    # --tag selecting this job's snapshots, the default would apply the policy
    # separately per path set - so changing a job's paths would split it into two
    # groups, each keeping its own newest N, stranding the old group's tail for good.
    # Empty means one group, which is what "this job's snapshots" should mean.
    $keep_args = [
      $keep_last    ? { undef => undef, default => "--keep-last ${keep_last}" },
      $keep_hourly  ? { undef => undef, default => "--keep-hourly ${keep_hourly}" },
      $keep_daily   ? { undef => undef, default => "--keep-daily ${keep_daily}" },
      $keep_weekly  ? { undef => undef, default => "--keep-weekly ${keep_weekly}" },
      $keep_monthly ? { undef => undef, default => "--keep-monthly ${keep_monthly}" },
      $keep_yearly  ? { undef => undef, default => "--keep-yearly ${keep_yearly}" },
    ].filter |$arg| { $arg =~ NotUndef }

    if empty($keep_args) {
      # Nothing else forgets anything now that retention belongs to the job, and unlike
      # a retired job this one keeps making snapshots - so say so rather than letting
      # it be discovered from a storage bill. Not a failure: keeping everything is a
      # legitimate policy, it just has to be a deliberate one.
      warning("sunet::backup::restic::job['${title}']: no keep_* value is set, so nothing \
will ever forget this job's snapshots and they will accumulate indefinitely. Set one of \
keep_last/keep_hourly/keep_daily/keep_weekly/keep_monthly/keep_yearly, or accept it knowingly.")
    }

    # undef rather than an empty string, so the template can branch on it
    $forget_args = empty($keep_args) ? {
      true    => undef,
      default => join(["--group-by ''"] + $keep_args, ' '),
    }

    # cron rejects a shorthand schedule combined with explicit fields, so an explicit
    # field wins over the 'daily' default rather than producing an obscure error.
    $explicit_schedule = [$hour, $minute, $weekday, $monthday].any |$field| { $field =~ NotUndef }
    $_special = $explicit_schedule ? {
      true    => undef,
      default => $special,
    }

    # Quote in Puppet rather than in the template, so the template only ever
    # interpolates strings that are already safe to paste into a shell.
    $quoted = {
      'env_file'           => shellquote($env_file),
      'restic_bin'         => shellquote($restic_bin),
      'pre_dir'            => shellquote($pre_dir),
      'post_dir'           => shellquote($post_dir),
      # Already reduced to [0-9A-Za-z._-], so it is safe to interpolate into a
      # double-quoted shell string without quoting of its own - which shellquote would
      # have nested and broken.
      'safe_repository'    => $safe_repository,
      'paths'              => $paths.map |$path| { shellquote($path) },
      'exclude'            => $exclude.map |$pattern| { shellquote($pattern) },
      'exclude_if_present' => $exclude_if_present.map |$filename| { shellquote($filename) },
      'tags'               => $restic_tags.map |$tag| { shellquote($tag) },
      'extra_args'         => $extra_args.map |$arg| { shellquote($arg) },
    }

    file { $job_dir:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      mode   => '0700',
    }

    # Purged so that a hook dropped from $pre_hooks/$post_hooks disappears from disk.
    # Puppet only purges children it does not manage, so the hooks declared below are
    # untouched.
    file { [$pre_dir, $post_dir]:
      ensure  => 'directory',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      recurse => true,
      purge   => true,
      force   => true,
      require => File[$job_dir],
    }

    # The hash key is the filename, so it carries the execution order too - sorted here
    # only so that $hook_files below has a stable order in the catalog.
    $pre_files  = $pre_hooks.keys.sort.map  |$hook| { "${pre_dir}/${hook}" }
    $post_files = $post_hooks.keys.sort.map |$hook| { "${post_dir}/${hook}" }
    $hook_files = ($pre_files + $post_files).map |$path| { File[$path] }

    $hooks_by_dir = {
      $pre_dir  => $pre_hooks,
      $post_dir => $post_hooks,
    }

    $hooks_by_dir.each |$dir, $specs| {
      $specs.each |$hook, $spec| {
        # The key is written out verbatim as a filename, so a stray '/' or space is
        # refused rather than silently mangled into something the operator did not ask
        # for - and the name ends up in backup.sh's expected-hook list either way.
        if $hook !~ /\A[0-9A-Za-z._\-]+\z/ {
          fail("sunet::backup::restic::job['${title}']: hook name '${hook}' becomes a \
filename, so it may only contain [0-9A-Za-z._-]")
        }

        if length([$spec['source'], $spec['template']].filter |$value| { $value =~ NotUndef }) != 1 {
          fail("sunet::backup::restic::job['${title}']: hook '${hook}' needs exactly one \
of 'source' or 'template'")
        }

        # Rendered in this define's scope, so a hook template can read the job's own
        # variables - $safe_name, $paths, $repository.
        $hook_content = $spec['template'] ? {
          undef   => undef,
          default => template($spec['template']),
        }

        # A hook stays a script of its own rather than being inlined into backup.sh: it
        # keeps its shebang, so it can be written in whatever language suits it, and it
        # can be run by hand on the host to test it.
        file { "${dir}/${hook}":
          ensure  => 'file',
          owner   => 'root',
          group   => 'root',
          mode    => '0700',
          source  => $spec['source'],
          content => $hook_content,
          require => File[$dir],
        }
      }
    }

    file { $script:
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0700',
      content => template('sunet/backup/restic/backup.sh.erb'),
      require => File[$job_dir],
    }

    sunet::scriptherder::cronjob { "restic-backup-${safe_name}":
      cmd           => $script,
      special       => $_special,
      hour          => $hour,
      minute        => $minute,
      weekday       => $weekday,
      monthday      => $monthday,
      random_sleep  => $random_sleep,
      ok_criteria   => ['exit_status=0', "max_age=${max_age}"],
      # 4 is backup.sh refusing to run against a hook set that does not match what it
      # expects, i.e. puppet was mid-run. Transient by nature, so a warning - and if it
      # somehow persists, max_age escalates it without any extra logic here.
      warn_criteria => ['exit_status=3', 'exit_status=4'],
      # The hooks as well as the script: this is what stops the cron entry from existing
      # before the hooks it is supposed to run. Without it a fresh node installs cron
      # first, and the first firing backs up whatever the pre hooks had not yet created.
      require       => [File[$script]] + $hook_files,
    }
  }
}
