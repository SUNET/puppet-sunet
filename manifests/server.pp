define sunet::server() {

  # fail2ban
  class { 'sunet::fail2ban': }

  # Set up encrypted swap
  sunet::encrypted_swap { 'sunet_encrypted_swap': }

  # Add prerequisites for ethernet bonding, if physical server
  sunet::ethernet_bonding { 'sunet_ethernet_bonding': }

# Removed until SWAMID hosts can have their ufw module updated  / ft
#  # Ignore IPv6 multicast
#  ufw::deny { 'ignore_v6_multicast':
#    ip    => 'ff02::1',
#    proto => 'any'  # 'ufw' has a hard-coded list of protocols, which does not include 'ipv6-icmp' :(
#  }

#  # Ignore IPv6 multicast PIM router talk
#  ufw::deny { 'ignore_v6_multicast_PIM':
#    ip    => 'ff02::d',
#    proto => 'any'  # 'ufw' has a hard-coded list of protocols, which does not include 'ipv6-icmp' :(
#  }

  include augeas
  augeas { "sshd_config":
    context => "/files/etc/ssh/sshd_config",
    changes => [
      "set PasswordAuthentication no",
      "set X11Forwarding no",
      "set LogLevel VERBOSE",  # log pubkey used for root login
    ],
    notify => Service['ssh'],
  } ->
    file_line {
      'no_sftp_subsystem':
        path        => '/etc/ssh/sshd_config',
        match       => 'Subsystem sftp /usr/lib/openssh/sftp-server',
        line        => '#Subsystem sftp /usr/lib/openssh/sftp-server',
    notify => Service['ssh'],
  }

  # already declared in puppet-cosmos/manifests/ntp.pp
  #service { 'ntp':
  #  ensure    => 'running',
  #}

  # Don't use pool.ntp.org servers, but rather DHCP provided NTP servers
  line { 'no_pool_ntp_org_servers':
      file        => '/etc/ntp.conf',
      line        => '^server .*\.pool\.ntp\.org',
      ensure      => 'comment',
      notify      => Service['ntp'],
  }

  file { '/var/cache/scriptherder':
    ensure  => 'directory',
    path    => '/var/cache/scriptherder',
    mode    => '1777',    # like /tmp, so user-cronjobs can also use scriptherder
  }


}

# from http://projects.puppetlabs.com/projects/puppet/wiki/Simple_Text_Patterns/5
define line($file, $line, $ensure = 'present') {
  case $ensure {
    default : { err ( "unknown ensure value ${ensure}" ) }
    present: {
      exec { "/bin/echo '${line}' >> '${file}'":
        unless => "/bin/grep -qFx '${line}' '${file}'"
      }
    }
    absent: {
      exec { "/usr/bin/perl -ni -e 'print unless /^\\Q${line}\\E\$/' '${file}'":
        onlyif => "/bin/grep -qFx '${line}' '${file}'"
      }
    }
    uncomment: {
      exec { "/bin/sed -i -e'/${line}/s/^#\\+//' '${file}'":
        onlyif => "/bin/grep '${line}' '${file}' | /bin/grep '^#' | /usr/bin/wc -l"
      }
    }
    comment: {
      exec { "/bin/sed -i -e'/${line}/s/^\\(.\\+\\)$/#\\1/' '${file}'":
        onlyif => "/usr/bin/test `/bin/grep '${line}' '${file}' | /bin/grep -v '^#' | /usr/bin/wc -l` -ne 0"
      }
    }
  }

}
