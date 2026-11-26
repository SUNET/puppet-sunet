# All database traffic stays on the dedicated rootless bridge.
class sunet::hittade2 (
  Pattern[/\A[a-z0-9][a-z0-9.-]*\z/] $hostname,
  Pattern[/\A[a-zA-Z0-9_.-]+\z/] $postgres_secret,
  Integer[1024,65535] $web_port = 18001,
  String $web_level = 's0:c100,c102',
  String $postgres_level = 's0:c106,c107',
  String $redis_level = 's0:c108,c109',
  Optional[Pattern[/\A[a-zA-Z0-9_.-]+\z/]] $django_secret = undef,
  String $web_profile = 'sunet/hittade/1',
  String $postgres_profile = 'sunet/postgres/1',
  String $redis_profile = 'sunet/redis/1',
) {
  include sunet::inventpod
  sunet::inventpod::vhost { $hostname: backend => '169.254.1.3', port => $web_port }
  $data = $sunet::inventpod::data_root
  exec { 'create hittade rootless network':
    command => '/usr/local/libexec/sunet-podman2/network create',
    unless  => '/usr/local/libexec/sunet-podman2/network exists',
    require => Exec['enable linger for barnbarn'],
    before  => Exec['qualify rootless podman2 releases'],
  }
  file { '/usr/local/libexec/sunet-podman2/network':
    source => 'puppet:///modules/sunet/podman2/network', mode => '0755',
    before => Exec['create hittade rootless network'],
  }
  sunet::podman2::container { 'hittade-postgres':
    profile => $postgres_profile, level => $postgres_level,
    quadlet => template('sunet/podman2/postgres.container.erb'),
    bindings => { 'database' => { 'path' => "${data}/postgres/database", 'level' => $postgres_level } },
  }
  sunet::podman2::container { 'hittade-redis':
    profile => $redis_profile, level => $redis_level,
    quadlet => file('sunet/podman2/redis.container'),
    bindings => { 'data' => { 'path' => "${data}/redis/data", 'level' => $redis_level } },
  }
  $private = ['certificates','settings','urls','proxy','css','staticfiles'].reduce({}) |$acc,$key| {
    $acc + { $key => { 'path' => "${data}/hittade/${key}", 'level' => $web_level } }
  }
  sunet::podman2::container { 'hittade-web':
    profile => $web_profile, level => $web_level,
    quadlet => template('sunet/podman2/hittade.container.erb'),
    after_units => ['hittade-postgres','hittade-redis'],
    bindings => $private + { 'hosts' => { 'path' => "${data}/reports/hosts", 'level' => $sunet::inventpod::report_level } },
  }
}
