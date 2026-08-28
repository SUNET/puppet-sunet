# @param job     title of the sunet::backup::restic::job this hook belongs to
# @param phase   'pre' to run before the backup, 'post' to run after it
# @param order   0-99, zero padded into the filename to control execution order.
#                Inline pre_hook/post_hook on the job itself use 0.
# @param content the script, as a string. Mutually exclusive with $source.
# @param source  a Puppet file source for the script, e.g.
#                'puppet:///modules/sunet/mariadb/dump-for-restic'. Mutually exclusive
#                with $content.
# @param ensure  set to 'absent' to remove the script
define sunet::backup::restic::hook (
  String                   $job,
  Enum['pre','post']       $phase,
  Integer[0,99]            $order   = 50,
  Optional[String]         $content = undef,
  Optional[String]         $source  = undef,
  Enum['present','absent'] $ensure  = 'present',
) {
  # Only the directory layout, never the main class - see the header of dirs.pp for
  # why that distinction matters.
  include sunet::backup::restic::dirs

  if $ensure != 'absent' and empty([$content, $source].filter |$arg| { $arg =~ NotUndef }) {
    fail("sunet::backup::restic::hook['${title}']: one of 'content' or 'source' must be given")
  }

  if $content =~ NotUndef and $source =~ NotUndef {
    fail("sunet::backup::restic::hook['${title}']: 'content' and 'source' are mutually exclusive")
  }

  $safe_name = regsubst($title, '[^0-9A-Za-z._\-]', '_', 'G')
  $safe_job  = regsubst($job, '[^0-9A-Za-z._\-]', '_', 'G')

  $phase_dir = "${sunet::backup::restic::dirs::jobs_dir}/${safe_job}/${phase}.d"
  $path      = sprintf('%s/%02d-%s', $phase_dir, $order, $safe_name)

  $_ensure = $ensure ? {
    'present' => 'file',
    'absent'  => 'absent',
  }

  file { $path:
    ensure  => $_ensure,
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => $content,
    source  => $source,
  }
}
