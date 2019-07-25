class sunet::telegraf::input { }

class sunet::telegraf::input::bind {
  sunet::telegraf::plugin {'bind': }
}

class sunet::telegraf::input::docker {
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
