class sunet::auditd {
   package { 'auditd': ensure => latest }
   service { 'auditd': ensure => running }
   augeas {'enable_auditd_syslog':
      changes => ["set /files/etc/audisp/plugins.d/syslog.conf/active yes"],
      notify  => Service['auditd']
   }
}
