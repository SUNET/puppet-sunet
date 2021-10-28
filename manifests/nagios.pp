include stdlib
include concat

class sunet::nagios($nrpe_service = 'nagios-nrpe-server') {

  $nagios_ip_v4 = hiera('nagios_ip_v4', '109.105.111.111')
  $nagios_ip_v6 = hiera('nagios_ip_v6', '2001:948:4:6::111')
  $nrpe_clients = hiera_array('nrpe_clients',['127.0.0.1','127.0.1.1',$nagios_ip_v4,$nagios_ip_v6])
  #$allowed_hosts = "127.0.0.1,127.0.1.1,${nagios_ip_v4},${nagios_ip_v6}"


  $allowed_hosts = join($nrpe_clients,',')

  $thruk_local_config = '# File managed by puppet
  <Component Thruk::Backend>
    <peer>
        name   = Core
        type   = livestatus
        <options>
            peer          = /var/cache/thruk/live.sock
            resource_file = /etc/nagios4/resource.cfg
       </options>
       <configtool>
            core_conf      = /etc/nagios4/nagios.cfg
            obj_check_cmd  = /usr/sbin/nagios4 -v /etc/nagios4/nagios.cfg
           obj_reload_cmd  = systemctl reload nagios4.service
       </configtool>
    </peer>
</Component>
cookie_auth_restricted_url = https://monitor.drive.sunet.se/thruk/cgi-bin/restricted.cgi
'

  package {$nrpe_service:
      ensure => 'installed',
  }
  -> service {$nrpe_service:
      ensure  => 'running',
      enable  => 'true',
      require => Package[$nrpe_service],
  }
  concat {'/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg':
      owner  => root,
      group  => root,
      mode   => '0644',
      notify => Service[$nrpe_service]
  }
  file_line {'nagios_livestatus_conf':
    line => 'broker_module=/usr/local/lib/mk-livestatus/livestatus.o /var/cache/thruk/live.sock',
    path => '/etc/nagios4/nagios.cfg'
  }
  file_line {'nagiosadmin_cgi_conf':
    line    => 'authorized_for_admin=nagiosadmin',
    match   => '^authorized_for_admin=thrukadmin',
    path    => '/etc/thruk/cgi.cfg',
    require => Package['thruk'],
  }
  concat::fragment {'sunet_nrpe_commands':
      target  => '/etc/nagios/nrpe.d/sunet_nrpe_commands.cfg',
      content => '# Do not edit by hand - maintained by puppet',
      order   => '10',
      notify  => Service[$nrpe_service]
  }
  file { '/etc/nagios/nrpe.cfg' :
      ensure  => 'file',
      notify  => Service[$nrpe_service],
      mode    => '0640',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/nrpe.cfg.erb'),
  }
  exec {'mk-livestatus-src':
      command => 'curl -s https://download.checkmk.com/checkmk/1.5.0p24/mk-livestatus-1.5.0p24.tar.gz --output /opt/mk-livestatus-1.5.0p24.tar.gz',
      unless  => 'ls /usr/local/lib/mk-livestatus/livestatus.o',
  }
  exec {'mk-livestatus-tar':
    command => 'cd /opt && tar xfv mk-livestatus-1.5.0p24.tar.gz',
    require => Exec['mk-livestatus-src'],
    unless  => 'ls /usr/local/lib/mk-livestatus/livestatus.o',
  }
  exec {'mk-livestatus-build':
    command => 'apt update && apt install -y make libboost-system1.71.0 clang librrd-dev libboost-dev libasio-dev libboost-system-dev && cd /opt/mk-livestatus-1.5.0p24 && ./configure --with-nagios4 && make && make install && apt -y remove clang librrd-dev libboost-dev libasio-dev libboost-system-dev make && apt autoremove -y',
    require => [Exec['mk-livestatus-tar'], File_line['nagios_livestatus_conf'], Exec['www-data_in_nagios_group']],
    unless  => 'ls /usr/local/lib/mk-livestatus/livestatus.o',
  }
  exec {'www-data_in_nagios_group':
    command => 'usermod -a -G nagios www-data && usermod -a -G www-data nagios',
    unless  => 'id www-data | grep nagios',
  }
  package {'thruk':
      ensure  => 'installed',
      require => Exec['mk-livestatus-build'],
  }
  package {'thruk-plugin-reporting':
      ensure  => 'installed',
      require => Package['thruk'],
  }
  file { 'thruk_repo' :
      ensure  => 'file',
      name    => '/etc/apt/sources.list.d/labs-consol-stable.list',
      mode    => '0640',
      content => 'deb http://labs.consol.de/repo/stable/ubuntu focal main',
      require =>  Exec['thruk_gpg_key'],
  }
  file { 'thruk_conf' :
      ensure  => 'file',
      name    => '/etc/thruk/thruk_local.conf',
      mode    => '0640',
      owner    => 'www-data',
      group   => 'www-data',
      content => $thruk_local_config,
      require => Package['thruk'],
  }
  exec { 'thruk_gpg_key':
      command => 'curl -s "https://labs.consol.de/repo/stable/RPM-GPG-KEY" | sudo apt-key add -',
      unless  => 'apt-key list 2> /dev/null | grep "F2F9 7737 B59A CCC9 2C23  F8C7 F8C1 CA08 A57B 9ED7"',
  }
  sunet::nagios::nrpe_command {'check_users':
    command_line => '/usr/lib/nagios/plugins/check_users -w 5 -c 10'
  }
  sunet::nagios::nrpe_command {'check_load':
    command_line => '/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20'
  }
  if $::fqdn == 'docker.sunet.se' {
    sunet::nagios::nrpe_command {'check_root':
        command_line => '/usr/lib/nagios/plugins/check_disk -w 4% -c 2% -p /'
    }
  } else {
    sunet::nagios::nrpe_command {'check_root':
        command_line => '/usr/lib/nagios/plugins/check_disk -w 15% -c 5% -p /'
    }
  }
  sunet::nagios::nrpe_command {'check_boot':
    command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /boot'
  }
  if $::fqdn == 'docker.sunet.se' {
    sunet::nagios::nrpe_command {'check_var':
        command_line => '/usr/lib/nagios/plugins/check_disk -w 4% -c 2% -p /var'
    }
  } else {
    sunet::nagios::nrpe_command {'check_var':
        command_line => '/usr/lib/nagios/plugins/check_disk -w 20% -c 10% -p /var'
    }
  }
  sunet::nagios::nrpe_command {'check_zombie_procs':
    command_line => '/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z'
  }
  if $::operatingsystem == 'Ubuntu' and versioncmp($::operatingsystemrelease, '12.04') <= 0 {
    sunet::nagios::nrpe_command {'check_total_procs_lax':
        command_line => '/usr/lib/nagios/plugins/check_procs -w 150 -c 200'
    }
  } else {
    if is_hash($facts) and has_key($facts, 'cosmos') and ('frontend_server' in $facts['cosmos']['host_roles']) {
      # There are more processes than normal on frontend hosts
      sunet::nagios::nrpe_command {'check_total_procs_lax':
        command_line => '/usr/lib/nagios/plugins/check_procs -k -w 500 -c 750'
      }
    } else {
      sunet::nagios::nrpe_command {'check_total_procs_lax':
        command_line => '/usr/lib/nagios/plugins/check_procs -k -w 150 -c 200'
      }
    }
  }
  sunet::nagios::nrpe_command {'check_uptime':
    command_line => '/usr/lib/nagios/plugins/check_uptime.pl -f'
  }
  sunet::nagios::nrpe_command {'check_reboot':
    command_line => '/usr/lib/nagios/plugins/check_reboot'
  }
  sunet::nagios::nrpe_command {'check_status':
    command_line => '/usr/local/bin/check_status'
  }
  sunet::nagios::nrpe_command {'check_mailq':
    command_line => '/usr/lib/nagios/plugins/check_mailq -w 20 -c 100'
  }
  file { '/usr/lib/nagios/plugins/check_uptime.pl' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_uptime.pl.erb'),
  }
  file { '/usr/lib/nagios/plugins/check_reboot' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_reboot.erb'),
  }
  file { '/usr/lib/nagios/plugins/check_process' :
      ensure  => 'file',
      mode    => '0751',
      group   => 'nagios',
      require => Package['nagios-nrpe-server'],
      content => template('sunet/nagioshost/check_process.erb'),
  }
  if ($::operatingsystem == 'Ubuntu' and $::operatingsystemmajrelease == '16.04') {
    file { '/usr/lib/nagios/plugins/check_memory':
        ensure  => 'file',
        mode    => '0751',
        group   => 'nagios',
        require => Package['nagios-nrpe-server'],
        content => template('sunet/nagioshost/check_memory_patched_806598.erb'),
    }
  }
  $nrpe_clients.each |$client| {
    $client_name = regsubst($client,'([.:]+)','_','G')
    ufw::allow { "allow-nrpe-${client_name}":
        from  => "${client}",
        ip    => 'any',
        proto => 'tcp',
        port  => '5666',
    }
  }
}
