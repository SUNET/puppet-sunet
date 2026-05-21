# This is a class that configures ipmi on supermicro servers.
# it can setup network configuration, admin password and add nrpe checks that look for hardware issues.
class sunet::ipmi (
  Integer                     $channel            = 1,
  Boolean                     $include_monitoring = true,
  Integer                     $admin_user_id      = 2,
  Integer                     $password_max_length = 20, # can be 16 or 20 depening on IPMI 1.5 or 2.0.
  Optional[String]            $ipaddr,
  Optional[String]            $netmask,
  Optional[String]            $gateway,
  Optional[Sensitive[String]] $admin_pass         = Sensitive(safe_hiera('ipmi_password')), # Take note of password_max_length
) {
  package { 'ipmitool':
    ensure => installed,
  }

  if $ipaddr and $netmask and $gateway {
      notify { 'ipmi_ip_config_enabled':
        message => "IPMI: Networking (static, ipaddr=${ipaddr}, gw=${gateway})",
      }

      exec { 'set_ipmi_static':
        command => "ipmitool lan set ${channel} ipsrc static",
        unless  => "ipmitool lan print ${channel} | grep -q '^IP Address Source.*Static Address'",
        path    => ['/usr/bin', '/bin'],
        require => Package['ipmitool'],
      }

      exec { 'set_ipmi_ip':
        command => "ipmitool lan set ${channel} ipaddr ${ipaddr}",
        unless  => "ipmitool lan print ${channel} | grep -q '${ipaddr}'",
        path    => ['/usr/bin', '/bin'],
        require => Exec['set_ipmi_static'],
      }

      exec { 'set_ipmi_netmask':
        command => "ipmitool lan set ${channel} netmask ${netmask}",
        unless  => "ipmitool lan print ${channel} | grep -q '^Subnet Mask.*${netmask}\$'",
        path    => ['/usr/bin', '/bin'],
        require => Exec['set_ipmi_ip'],
      }

      exec { 'set_ipmi_gateway':
        command => "ipmitool lan set ${channel} defgw ipaddr ${gateway}",
        unless  => "ipmitool lan print ${channel} | grep -q '^Default Gateway IP.*${gateway}\$'",
        path    => ['/usr/bin', '/bin'],
        require => Exec['set_ipmi_netmask'],
      }
  } else {
      notify { 'ipmi_ip_config_skipped':
        message => 'IPMI: Networking (skipped)',
      }
  }

  if $admin_pass {
      notify { 'ipmi_password_update_enabled':
        message => 'IPMI: Password (enabled)',
      }

      exec { 'set_ipmi_password':
        command => "ipmitool user set password ${admin_user_id} '${admin_pass.unwrap}' ${password_max_length}",
        unless  => 'test -f /etc/ipmi_password_is_set',
        path    => ['/usr/bin', '/bin'],
        notify  => File['ipmi_password_is_set'],
      }

      # This file gets created when a password is set to stop repeating commands to the ipmi interface.
      # When rotating password you need to remove /etc/ipmi_password_is_set on the host to trigger a password update.
      file { 'ipmi_password_is_set':
        ensure  => present,
        path    => '/etc/ipmi_password_is_set',
        replace => false,
      }

  } else {
      notify { 'ipmi_password_skipped':
        message => 'IPMI: Password (skipped)',
      }
  }

  if $include_monitoring {
      notify { 'ipmi_monitoring_enabled':
        message => 'IPMI: Monitoring (enabled)',
      }

      # This file removes chassis intrusion detection on the ipmi sensor check.
      # This tend to be noice anyway.
      file { '/etc/check_ipmi_sensor.exclude':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => @("EOF"/L)
~.*Chassis.*|Physical Security
~.*Intrus.*|Physical Security
EOF
      }

      file { '/etc/nagios/nrpe.d/ipmi_monitor.cfg':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => "command[check_ipmi_sensor]=/usr/lib/nagios/plugins/check_ipmi_sensor --nosel -xx /etc/check_ipmi_sensor.exclude\n",
        require => File['/etc/check_ipmi_sensor.exclude'],
        notify  => Service['nagios-nrpe-server'],
      }

      file { '/etc/sudoers.d/nrpe-ipmi':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0440',
        content => join([
          '# Allow NRPE/Nagios to run FreeIPMI tools needed by check_ipmi_sensor without a tty/password',
          'Defaults:nagios !requiretty',
          'nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-sensors',
          'nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-sel',
          'nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-dcmi',
          'nagios ALL=(root) NOPASSWD: /usr/sbin/ipmi-fru',
          '',
        ], "\n"),
      }
    } else {
      notify { 'ipmi_monitoring_disabled':
        message => 'IPMI: Monitoring (skipped)',
      }
    }
  }
