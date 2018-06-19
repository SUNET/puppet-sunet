class sunet::auditd {
   package { 'auditd': ensure => latest }
   service { 'auditd': ensure => running }
   augeas {'enable_auditd_syslog':
      incl    => "/etc/audisp/plugins.d/syslog.conf",
      lens    => "Simplevars.lns",
      changes => ["set /files/etc/audisp/plugins.d/syslog.conf/active yes",
                  "set /files/etc/audisp/plugins.d/syslog.conf/args \"LOG_INFO\""],
      notify  => Service['auditd']
   }
   file { '/etc/audit/audit.rules': 
      content => templates("sunet/audit/audit.rules.erb"),
      mode    => '0600',
      notify  => Service['auditd']
   }
}
