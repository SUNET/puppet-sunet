# telegraf
class sunet::telegraf($repo = 'stable') {
  $token = safe_hiera('influxdb_v2_token');
  if ($token == 'NOT_SET_IN_HIERA') {
    warning('Waiting to get influxdb_v2_token from hiera before configuring telegraf')
  } else {
    ensure_resource('file','/etc/default',{ ensure => directory });
    ensure_resource('sunet::misc::create_dir','/etc/cosmos/apt/keys',{ owner => 'root', group => 'root', mode => '0755' });
    file {'/etc/cosmos/apt/keys/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub':
        ensure  => file,
        mode    => '0644',
        content => template('sunet/telegraf/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub.erb'),
    }
    -> apt::key { 'telegraf':
      id     => '05CE15085FC09D18E99EFB22684A14CF2582E0C5',
      source => '/etc/cosmos/apt/keys/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub'
    }
    if $facts['os']['name'] == 'Ubuntu' and $facts['os']['release']['full'] == '14.04' {
      $architecture = 'amd64'
    } else {
      $architecture = undef
    }
    apt::source {'telegraf':
      location     => 'https://repos.influxdata.com/ubuntu',
      release      => $facts['os']['distro']['codename'],
      repos        => $repo,
      key          => {'id' => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'},
      architecture => $architecture
    }
    exec { 'telegraf_apt_get_update':
        command     => '/usr/bin/apt-get update',
        cwd         => '/tmp',
        require     => [Apt::Key['telegraf']],
        subscribe   => [Apt::Key['telegraf']],
        refreshonly => true,
    }
    $_provider = $facts['init_type'] ? {
        'upstart'      => 'upstart',
        'systemd-sysv' => 'systemd',
        default        => 'debian'
    }
    package { 'telegraf':
        ensure  => latest,
        require => Exec['telegraf_apt_get_update'],
    }
    -> file {'/etc/default/telegraf':
        ensure  => file,
        content => inline_template("INFLUXDB_V2_TOKEN=${token}\n")
    }
    -> service {'telegraf': ensure => running, provider => $_provider }
    file {'/etc/telegraf/telegraf.conf':
        ensure  => file,
        content => template('sunet/telegraf/telegraf-conf.erb'),
        notify  => Service['telegraf']
    }
    sunet::telegraf::plugin {'basic': }
  }
}
