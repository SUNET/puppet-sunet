class sunet::telegraf::input { }

class sunet::telegraf::input::bind {
  sunet::telegraf::plugin {'bind': }
}

class sunet::telegraf::input::docker {
  sunet::snippets::add_user_to_group {'add_telegraf_to_docker_group':
     user   => 'telegraf',
     group  => 'docker'
  }
  sunet::telegraf::plugin {'docker': }
}

class sunet::telegraf::input::ipmi {
  package {'ipmitool': ensure => latest } ->
  sunet::sudoer {'telegraf_run_ipmitool_sdr':
     user_name    => 'telegraf',
     collection   => 'telegraf',
     command_line => "/usr/bin/ipmitool sdr elist"
  }
  file {'/usr/bin/ipmitool_telegraf':
     ensure       => file,
     owner        => telegraf,
     group        => telegraf,
     mode         => '0755',
     content      => inline_template("#!/bin/sh\nexec sudo /usr/bin/ipmitool $*")
  }
  sunet::telegraf::plugin {'ipmi': config => {ipmitool_path => '/usr/bin/ipmitool_telegraf', timeout => "300s"}}
}

class sunet::telegraf::input::varnish(
  $use_sudo=false,
  $binary="/usr/bin/varnishstat",
  $stats=["MAIN.cache_hit", "MAIN.cache_miss", "MAIN.uptime"],
  $instance_name=undef,
  $timeout="1s",
  $container=undef) 
{
  if ($container) {
     file {"/usr/bin/telegraf_varnishstat_in_$container": 
        ensure   => file,
        owner    => root,
        group    => root,
        mode     => '0755',
        content  => inline_template("#!/bin/sh\ndocker exec -ti <%= @container %> <%= @binary %> $*\n")
     }
  }
  $_cmd = $container ? {
     undef   => $binary,
     default => "/usr/bin/telegraf_varnishstat_in_$container"
  }
  sunet::telegraf::plugin {'varnish': config => {
      use_sudo      => $use_sudo,
      binary        => $_cmd,
      stats         => $stats,
      instance_name => $instance_name,
      timeout       => $timeout}
  }
}
