# Wrapper to setup a MDQ "Proxy"
class sunet::metadata::mdqp(
  String  $imagetag      = 'latest',
  Integer $runs_per_hour = 4,
  String  $mdq_service   = 'https://mds.swamid.se',
  Boolean $mdq = true,
) {

      include sunet::packages::jq
      include sunet::packages::xmlstarlet
      include sunet::packages::xmllint

      $docker_class = $::facts['dockerhost2'] ? {
        yes => 'sunet::dockerhost2',
        default => 'sunet::dockerhost',
      }

      $image_tag = "docker.sunet.se/mdqp:${imagetag}"

      if $mdq {
        if ($::facts['dockerhost2'] == 'yes') {
          exec {'Fetch image':
            command => "/usr/bin/docker pull ${image_tag}",
            require => Class['sunet::dockerhost2'],
          }
        } else {
          docker::image { $image_tag :  # make it possible to use the same docker image more than once on a node
            ensure  => 'present',
            image   => $image_tag,
            require => Class['sunet::dockerhost'],
          }
        }
      }

      file { '/opt/mdqp':
        ensure => 'directory',
      }
      file { '/opt/mdqp/pre.d':
        ensure => 'directory',
      }
      file { '/opt/mdqp/post.d':
        ensure => 'directory',
      }
      package {
        [
          'libdate-calc-perl',
          'xmlsec1',
          'xsltproc',
        ]: ensure => latest
      }
      file { '/opt/mdqp/mdqp-wrapper':
        content => template('sunet/metadata/mdqp-wrapper.erb'),
        mode    => '0755',
        }
      sunet::scriptherder::cronjob { 'mdqp-wrapper':
        cmd           => '/opt/mdqp/mdqp-wrapper',
        minute        => '*/15',
        ok_criteria   => ['exit_status=0', 'max_age=2h'],
        warn_criteria => ['exit_status=1', 'max_age=5h'],
      }
}
