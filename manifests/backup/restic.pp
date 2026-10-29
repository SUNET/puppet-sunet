# @param version      restic release to install, without the leading 'v'
# @param sha256       sha256 of restic_${version}_linux_amd64.bz2, from the release's
#                     SHA256SUMS file. Must be changed together with $version - a
#                     stale hash makes Puppet refuse the download, which is the point
#                     of pinning it.
# @param repositories restic repositories, by default from the Hiera key
#                     restic_repositories
class sunet::backup::restic (
  String                $version      = '0.19.1',
  String                $sha256       = 'f415415624dcc452f2a02b8c33641791a8c6d6d3b65bbb3543fcf9a25151585c',
  Hash[String[1], Hash] $repositories = lookup('restic_repositories', Hash, undef, {}),
) {
  include sunet::packages::bzip2
  include sunet::backup::restic::dirs

  $bin_dir  = $sunet::backup::restic::dirs::bin_dir
  $dist_dir = $sunet::backup::restic::dirs::dist_dir
  $symlink  = $sunet::backup::restic::dirs::symlink

  $archive       = "restic_${version}_linux_amd64.bz2"
  $archive_path  = "${dist_dir}/${archive}"
  $versioned_bin = "${bin_dir}/restic-${version}"

  # Puppet verifies the hash before the file lands. checksum_value is also what
  # stops it from re-downloading on every run.
  file { $archive_path:
    ensure         => 'file',
    owner          => 'root',
    group          => 'root',
    mode           => '0644',
    source         => "https://github.com/restic/restic/releases/download/v${version}/${archive}",
    checksum       => 'sha256',
    checksum_value => $sha256,
    require        => File[$dist_dir],
  }

  # Upstream publishes the Linux binary only as bzip2 - there is no tar.gz or zip to
  # use instead - so bunzip2 is what unpacks it. Decompressed through a temporary
  # file and then moved into place, so an interrupted run cannot leave a truncated
  # binary that 'creates' would then consider finished.
  exec { "restic_unpack_${version}":
    command  => "bunzip2 -c ${shellquote($archive_path)} > ${shellquote("${versioned_bin}.tmp")} \
&& chmod 0755 ${shellquote("${versioned_bin}.tmp")} \
&& mv ${shellquote("${versioned_bin}.tmp")} ${shellquote($versioned_bin)}",
    provider => 'shell',
    path     => ['/usr/local/bin', '/usr/bin', '/bin'],
    creates  => $versioned_bin,
    require  => [File[$archive_path], File[$bin_dir], Class['sunet::packages::bzip2']],
  }

  # Old versions are deliberately left on disk, so rolling back is a $version change
  # that moves this symlink without re-downloading anything.
  file { $symlink:
    ensure  => 'link',
    target  => $versioned_bin,
    require => Exec["restic_unpack_${version}"],
  }

  $repositories.each |$repo_name, $repo_params| {
    ensure_resource('sunet::backup::restic::repository', $repo_name, $repo_params)
  }
}
