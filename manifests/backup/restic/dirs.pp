# @param install_dir holds everything restic: the versioned binaries, the downloaded
#                    archives, restic's cache, and the repository and job configuration
# @param symlink     unversioned symlink pointing at the installed binary. Lives here
#                    rather than in the main class because jobs and the operator
#                    wrapper need the binary path but must not need the version.
class sunet::backup::restic::dirs (
  String $install_dir = '/opt/restic',
  String $symlink     = '/usr/local/bin/restic',
) {
  $bin_dir   = "${install_dir}/bin"
  $dist_dir  = "${install_dir}/dist"
  $cache_dir = "${install_dir}/cache"
  $repos_dir = "${install_dir}/repos.d"
  $jobs_dir  = "${install_dir}/jobs.d"

  file {
    default:
      ensure => 'directory',
      owner  => 'root',
      group  => 'root',
      ;
    [$install_dir, $bin_dir, $dist_dir]:
      mode => '0755',
      ;
    $cache_dir:
      mode => '0700',
      ;
    $repos_dir:
      # holds repository passwords and object store credentials
      mode => '0700',
      ;
    $jobs_dir:
      # Purged one level deep so that a job that is no longer declared does not leave
      # its directory behind. Puppet only purges children it does not manage, so live
      # jobs keep their files and their own modes.
      mode         => '0755',
      recurse      => true,
      recurselimit => 1,
      purge        => true,
      force        => true,
      ;
  }
}
