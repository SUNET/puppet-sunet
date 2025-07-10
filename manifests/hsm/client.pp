# The HSM client
class sunet::hsm::client (
  String  $tarball               = '610-000397-015_SW_Linux_Luna_Client_V10.9.0_RevB.tar',
  String  $baseurl               = 'https://sunet.drive.sunet.se/s/4z96YiBA2c3oFo3/download',
  String  $shasum                = '8f5644e0aced01ac5718db41321d0fb6c21c5f9c80dbeda815b39cb735139e2f',
  Array   $hsm_servers           = ['tug-hsm-lab2.sunet.se'],
  Array   $allow_remote_ped_from = [],
  Boolean $monitor               = false,
) {

  include sunet::packages::alien

  file { '/opt/hsmclient':
    ensure => directory,
  }
  file { '/opt/hsmclient/libexec':
    ensure => directory,
  }

  file { '/opt/hsmclient/libexec/download-patch-and-install':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/hsm/download-patch-and-install')
  }

  exec { '/opt/hsmclient/libexec/download-patch-and-install':
    command => "/opt/hsmclient/libexec/download-patch-and-install ${tarball} ${baseurl} ${shasum}",
    creates => '/usr/safenet/lunaclient/bin/lunacm',
  }

  sunet::snippets::file_line { 'path-to-luna':
    ensure   => 'present',
    filename => '/root/.bashrc',
    line     => 'export PATH=$PATH:/usr/safenet/lunaclient/bin',
  }

  $hsm_servers.each  | $hsm | {

    file { "/usr/safenet/lunaclient/cert/server/${hsm}Cert.pem":
      ensure  => 'file',
      mode    => '0750',
      owner   => 'root',
      content => file("sunet/hsm/servers/${hsm}Cert.pem")
    }
  }

  file { '/opt/hsmclient/libexec/configure-luna':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('sunet/hsm/configure-luna')
  }

  exec { '/opt/hsmclient/libexec/configure-luna':
    onlyif =>  'test `grep  sunet.se /etc/Chrystoki.conf |wc -l` -eq 0',
  }

  if ($allow_remote_ped_from) {
    sunet::nftables::allow{ 'ped':
      from => $allow_remote_ped_from,
      port => 1503,
    }

    file_line { 'enable-GatewayPorts':
      path   => '/etc/ssh/sshd_config',
      line   => 'GatewayPorts yes',
      match  => '^#?GatewayPorts',
      notify => Service['ssh'],
    }
  }
  if ($monitor) {
    $pin = lookup('partition_pin', undef, undef, 'NOT_SET_IN_HIERA');
    file { '/root/hsm-partition-pin':
      ensure  => 'file',
      mode    => '0700',
      owner   => 'root',
      content => template('sunet/hsm/hsm-partition-pin.erb')
    }

    file { '/usr/lib/nagios/plugins/check_hsm':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/hsm/check-hsm.sh')
    }
    sunet::sudoer { 'nagios_hsm':
      user_name    => 'nagios',
      collection   => 'hsm',
      command_line => '/usr/lib/nagios/plugins/check_hsm',
    }

    file { '/usr/safenet/lunaclient/cert/safenet-root.pem':
      ensure  => 'file',
      mode    => '0644',
      owner   => 'root',
      content => file('sunet/hsm/safenet-root.pem')
    }

    $hsm_servers.each  | $hsm | {
      $dc =  split($hsm,'-')[0]
      sunet::nagios::nrpe_command { "check_hsm_${dc}":
        command_line => "/usr/bin/sudo /usr/lib/nagios/plugins/check_hsm ${dc}",
      }
    }
  }

}
