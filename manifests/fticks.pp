class sunet::fticks($ensure=present,$url=undef,$args='',$pipe='/dev/fticks') {
  $_ensure_file = $ensure ? {
      'present'   => 'file',
      'absent'    => 'absent'
  }
  $_ensure_service = $ensure ? {
      'present'   => 'running',
      'absent'    => 'absent'
  }
  $_ensure_fifo = $ensure ? {
      'present'   => 'fifo',
      'absent'    => 'absent'
  }
  package {['python3-dateutil','python3-daemon']:
      ensure      => 'latest'
  }
  sunet::remote_file{'/usr/sbin/fticks':
      ensure          => $_ensure_file,
      mode            => '0755',
      remote_location => 'https://raw.githubusercontent.com/SUNET/flog/master/scripts/fticks.py'
  }
  exec {"create ${pipe}":
      command => "mkfifo ${pipe} && chown ${pipe}",
      onlyif  => "test ! -p ${pipe}"
  }
  file {'/etc/systemd/system/fticks.service':
      ensure  => $_ensure_file,
      content => template('sunet/fticks/fticks.service.erb')
  }
  file {'/etc/rsyslog.d/70-sunet-fticks-pipe.conf':
      ensure  => $_ensure_file,
      content => inline_template(":rawmsg,contains,\"F-TICKS\" |${pipe}\n"),
  }
  service {'fticks':
      ensure           => $_ensure_service
  }
}
