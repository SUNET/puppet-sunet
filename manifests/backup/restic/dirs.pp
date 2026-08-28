# The restic directory layout, and the path variables every other part of the module
# reads.
#
# This class exists so that nothing except cosmos-rules ever has to declare
# sunet::backup::restic. It holds no version and downloads nothing, so it is safe to
# `include` from anywhere, any number of times - which is what lets
# sunet::backup::restic::{repository,job,hook} find their paths without pulling in the
# main class as a side effect.
#
# Do not merge this back into sunet::backup::restic. The main class is declared from
# cosmos-rules as `class { 'sunet::backup::restic': version => ... }`, and a
# resource-like declaration may only happen once and must come before anything that
# `include`s the same class. If the defines included the main class, declaring a job
# from a service class would evaluate it first with default parameters, and the
# cosmos-rules declaration would then fail with
# 'Duplicate declaration: Class[Sunet::Backup::Restic] is already declared'.
#
# It also owns the pre.d/post.d parent, so a service class can drop backup hooks in
# without depending on the main class.
#
# Both parameters are set through Hiera automatic parameter lookup, since this class
# is included rather than declared:
#
#   sunet::backup::restic::dirs::install_dir: '/local/restic'
#
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
