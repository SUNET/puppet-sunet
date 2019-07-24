class sunet::telegraph($repo = 'stable') {
  sunet::misc::create_dir { '/etc/cosmos/apt/keys': owner => 'root', group => 'root', mode => '0755'} ->
  file {
    '/etc/cosmos/apt/keys/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub':
      ensure  => file,
      mode    => '0644',
      content => template('sunet/telegraph/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub.erb'),
  } ->
  apt::key { 'telegraph':
    id        => '05CE15085FC09D18E99EFB22684A14CF2582E0C5',
    source    => '/etc/cosmos/apt/keys/influxdb-05CE15085FC09D18E99EFB22684A14CF2582E0C5.pub'
  }
  if $::operatingsystem == 'Ubuntu' and $::operatingsystemrelease == '14.04' {
    $architecture = 'amd64'
  } else {
    $architecture = undef
  }
  apt::source {'telegraph':
    location  => 'https://repos.influxdata.com/ubuntu',
    release   => $::lsbdistcodename,
    repos        => $repo,
    key          => {'id' => '9DC858229FC7DD38854AE2D88D81803C0EBFCD88'},
    architecture => $architecture
  }
  exec { 'telegraph_apt_get_update':
     command     => '/usr/bin/apt-get update',
     cwd         => '/tmp',
     require     => [Apt::Key['telegraph']],
     subscribe   => [Apt::Key['telegraph']],
     refreshonly => true,
  }
  package { 'telegraph':
     ensure => latest,
     require => Exec['telegraph_apt_get_update'],
  } -> service {'telegraph': ensure => running }
}
