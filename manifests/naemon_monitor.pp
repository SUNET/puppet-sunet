# Run naemon with Thruk
class sunet::naemon_monitor(
  String $domain,
  String $influx_password = hiera('influx_password'),
  String $naemon_tag = 'latest',
  Array $naemon_extra_volumes = [],
  Array $exclude_hosts = [],
  Array $resolvers = [],
  String $thruk_tag = 'latest',
  Array $thruk_admins = ['placeholder'],
  Array $thruk_users = [],
  String $influxdb_tag = '1.8',
  String $histou_tag = 'latest',
  String $nagflux_tag = 'latest',
  String $grafana_tag = '9.1.6',
  Hash $manual_hosts = {},
  Hash $additional_entities = {},
  String $nrpe_group = 'nrpe',
  Optional[String] $default_host_group = undef,
){

  require stdlib

  ufw::allow { 'naemon-allow-http':
    ip   => 'any',
    port => '80'
  }
  ufw::allow { 'naemon-allow-https':
    ip   => 'any',
    port => '443'
  }

  class { 'sunet::dehydrated::client': domain =>  $domain, ssl_links => true }

  if hiera('shib_key',undef) != undef {
    sunet::snippets::secret_file { '/opt/naemon_monitor/shib-certs/sp-key.pem': hiera_key => 'shib_key' }
    # assume cert is in cosmos repo (overlay)
  }

  $thruk_admins_string = inline_template('ADMIN_USERS=<%- @thruk_admins.each do |user| -%><%= user %>,<%- end -%>')
  $thruk_users_string = inline_template('READONLY_USERS=<%- @thruk_users.each do |user| -%><%= user %>,<%- end -%>')
  $thruk_env = [ $thruk_admins_string, $thruk_users_string ]

  $influx_env =  [ 'INFLUXDB_ADMIN_USER=admin',"INFLUXDB_ADMIN_PASSWORD=${influx_password}", 'INFLUXDB_DB=nagflux']
  $nagflux_env =  [ "INFLUXDB_ADMIN_PASSWORD=${influx_password}" ]

  file { '/etc/systemd/system/sunet-naemon_monitor.service.d/':
    ensure  => directory,
    recurse => true,
  }

  file { '/etc/systemd/system/sunet-naemon_monitor.service.d/override.conf':
    ensure  => file,
    content => template('sunet/naemon_monitor/service-override.conf'),
    require => File['/etc/systemd/system/sunet-naemon_monitor.service.d/'],
  }

  sunet::docker_compose { 'naemon_monitor':
    content          => template('sunet/naemon_monitor/docker-compose.yml.erb'),
    service_name     => 'naemon_monitor',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Naemon monitoring (with Thruk)',
    require          => File['/etc/systemd/system/sunet-naemon_monitor.service.d/override.conf'],
  }

  file { '/opt/naemon_monitor/stop-monitor.sh':
    ensure  => file,
    content => template('sunet/naemon_monitor/stop-monitor.sh'),
  }

  file { '/opt/naemon_monitor/grafana.ini':
    ensure  => file,
    content => template('sunet/naemon_monitor/grafana.ini'),
  }
  file { '/opt/naemon_monitor/histou.js':
    ensure  => file,
    content => template('sunet/naemon_monitor/histou.js'),
  }
  file { '/opt/naemon_monitor/influxdb.yaml':
    ensure  => file,
    content => template('sunet/naemon_monitor/influxdb.yaml'),
  }
  file { '/opt/naemon_monitor/data':
    ensure  => directory,
    owner   => 'www-data'
  }

  $nagioscfg_dirs = ['/etc/', '/etc/naemon/', '/etc/naemon/conf.d/', '/etc/naemon/conf.d/nagioscfg/', '/etc/naemon/conf.d/cosmos/']
    $nagioscfg_dirs.each |$dir| {
      ensure_resource('file',$dir, { ensure => directory} )
    }

  nagioscfg::contactgroup {'alerts': }
  -> nagioscfg::service {'check_load':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_load',
    description    => 'System Load',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_users':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_users',
    description    => 'Active Users',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_zombie_procs':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_zombie_procs',
    description    => 'Zombie Processes',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_total_procs':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_total_procs_lax',
    description    => 'Total Processes',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_dynamic_disk':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_dynamic_disk',
    description    => 'Disk',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }

  nagioscfg::service {'check_uptime':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_uptime',
    description    => 'Uptime',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_reboot':
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_reboot',
    description    => 'Reboot Needed',
    contact_groups => ['alerts'],
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_memory':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_memory',
    description    => 'System Memory',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_entropy':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_entropy',
    description    => 'System Entropy',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_ntp_time':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_ntp_time',
    description    => 'System NTP Time',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_scriptherder':
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_scriptherder',
    description    => 'Scriptherder Status',
    contact_groups => ['naemon-admins'],
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
  nagioscfg::service {'check_apt':
    use            => 'naemon-service',
    hostgroup_name => [$nrpe_group],
    check_command  => 'check_nrpe!check_apt',
    description    => 'Packages available for upgrade',
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }

  file { '/etc/naemon/conf.d/cosmos/naemon-hostgroups.cfg':
    ensure  => file,
    mode    => '0644',
    content => template('sunet/naemon_monitor/naemon-hostgroups.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }
  file { '/etc/naemon/conf.d/cosmos/naemon-host.cfg':
    ensure  => file,
    content => template('sunet/naemon_monitor/naemon-host.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  file { '/etc/naemon/conf.d/cosmos/naemon-service.cfg':
    ensure  => file,
    content => template('sunet/naemon_monitor/naemon-service.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  file { '/etc/naemon/conf.d/cosmos/naemon-contactgroups.cfg':
    ensure  => file,
    content => template('sunet/naemon_monitor/naemon-contactgroups.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  class { 'nagioscfg':
    hostgroups     => $::roles,
    exclude_hosts => $exclude_hosts,
    additional_entities => $additional_entities,
    config         => 'naemon_monitor',
    default_host_group => $default_host_group,
    manage_package => false,
    manage_service => false,
    cfgdir         => '/etc/naemon/conf.d/nagioscfg',
    host_template  => 'naemon-host',
    service        => 'sunet-naemon_monitor',
    single_ip      => true,
    require        => File['/etc/naemon/conf.d/nagioscfg/'],
  }
}
