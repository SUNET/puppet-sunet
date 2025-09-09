# The apt repo for docker
define sunet::apt::repo_docker (
) {
  apt::source { 'docker':
    location => "https://download.docker.com/linux/${lc_distro}",
    repos    => $docker_repo,
    key      => {
      name    => 'docker.asc',
      content => file('sunet/apt/docker.asc'),
    }
  }
  apt::pin { 'Pin docker repo':
    packages => '*',
    priority => 1,
    origin   => 'download.docker.com'
  }
}
