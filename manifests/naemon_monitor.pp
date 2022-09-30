# Run naemon with Thruk
class naemon::naemon_monitor(
  String $domain,
  String $influx_password = safe_hiera('influx_password'),
  String $naemon_tag = 'latest',
  Array $naemon_extra_volumes = [],
  String $thruk_tag = 'latest',
  Array $thruk_admins = ['placeholder'],
  Array $thruk_users = [],
  String $influxdb_tag = '1.8',
  String $histou_tag = 'latest',
  String $nagflux_tag = 'latest',
  String $grafana_tag = '9.1.6',
){

  require stdlib

  class { 'webserver': }

  class { 'sunet::dehydrated::client': domain =>  $domain, ssl_links => true }

  if hiera('shib_key',undef) != undef {
    sunet::snippets::secret_file { '/opt/cosmos/shib-certs/sp-key.pem': hiera_key => 'shib_key' }
    # assume cert is in cosmos repo (overlay)
  }

  $thruk_admins_string = inline_template('ADMIN_USERS=<%- @thruk_admins.each do |user| -%><%= user %>,<%- end -%>')
  $thruk_users_string = inline_template('READONLY_USERS=<%- @thruk_users.each do |user| -%><%= user %>,<%- end -%>')
  $thruk_env = [ $thruk_admins_string, $thruk_users_string ]

  $influx_env =  [ 'INFLUXDB_ADMIN_USER=admin',"INFLUXDB_ADMIN_PASSWORD=${influx_password}", 'INFLUXDB_DB=nagflux']
  $nagflux_env =  [ "INFLUXDB_ADMIN_PASSWORD=${influx_password}" ]

  sunet::docker_compose { 'naemon_monitor':
    content          => template('sunet/naemon_monitor/docker-compose.yml.erb'),
    service_name     => 'naemon_monitor',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'Naemon monitoring (with Thruk)',
    require          => File['/etc/systemd/system/sunet-naemon_monitor.service.d/override.conf'],
  }

  file { '/etc/systemd/system/sunet-naemon_monitor.service.d/override.conf':
    ensure  => file,
    content => template('sunet/naemon_monitor/service-override.conf'),
  }

  nagioscfg::contactgroup {'alerts': }
  -> nagioscfg::service {'check_load':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_load',
    description    => 'System Load',
  }
  nagioscfg::service {'check_users':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_users',
    description    => 'Active Users',
  }
  nagioscfg::service {'check_zombie_procs':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_zombie_procs',
    description    => 'Zombie Processes',
  }
  nagioscfg::service {'check_total_procs':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_total_procs_lax',
    description    => 'Total Processes',
  }
  nagioscfg::service {'check_root':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_root',
    description    => 'Root Disk',
  }
  nagioscfg::service {'check_boot':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_boot_15_5',
    description    => 'Boot Disk',
  }
  nagioscfg::service {'check_var':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_var',
    description    => 'Var Disk',
  }
  nagioscfg::service {'check_boot_inodes':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_boot_inodes_15_5',
    description    => 'Boot Disk Inodes',
  }
  nagioscfg::service {'check_root_inodes':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_root_inodes_15_5',
    description    => 'Root Disk Inodes',
  }

  nagioscfg::service {'check_uptime':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_uptime',
    description    => 'Uptime',
  }
  nagioscfg::service {'check_reboot':
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_reboot',
    description    => 'Reboot Needed',
    contact_groups => ['alerts']
  }
  nagioscfg::service {'check_memory':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_memory',
    description    => 'System Memory',
  }
  nagioscfg::service {'check_entropy':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_entropy',
    description    => 'System Entropy',
  }
  nagioscfg::service {'check_ntp_time':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_ntp_time',
    description    => 'System NTP Time',
  }
  nagioscfg::service {'check_scriptherder':
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_scriptherder',
    description    => 'Scriptherder Status',
    contact_groups => ['naemon-admins']
  }
  nagioscfg::service {'check_apt':
    use            => 'naemon-service',
    hostgroup_name => ['nrpe'],
    check_command  => 'check_nrpe!check_apt',
    description    => 'Packages available for upgrade',
  }

  file { '/etc/naemon/conf.d/cosmos/':
    ensure  => directory,
    recurse => true,
  }

  file { '/etc/naemon/conf.d/cosmos/hostgroups.cfg':
    ensure  => file,
    mode    => '0644',
    content => template('naemon/hostgroups.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }
  file { '/etc/naemon/conf.d/cosmos/naemon-host.cfg':
    ensure  => file,
    content => template('naemon/naemon-host.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  file { '/etc/naemon/conf.d/cosmos/naemon-service.cfg':
    ensure  => file,
    content => template('naemon/naemon-service.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  file { '/etc/naemon/conf.d/cosmos/naemon-contactgroups.cfg':
    ensure  => file,
    content => template('naemon/naemon-contactgroups.cfg.erb'),
    require => File['/etc/naemon/conf.d/cosmos/'],
  }

  class { 'nagioscfg':
    hostgroups     => $::roles,
    config         => 'naemon_monitor',
    manage_package => false,
    manage_service => false,
    cfgdir         => '/etc/naemon/conf.d/nagioscfg',
    host_template  => 'naemon-host',
    service        => 'sunet-naemon_monitor',
    single_ip      => true,
  }
}
