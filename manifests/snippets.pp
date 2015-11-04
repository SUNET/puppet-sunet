define sunet::snippets::ethernet_bonding() {
  # Set up prerequisites for Ethernet LACP bonding of eth0 and eth1,
  # for all physical hosts that are running Ubuntu.
  #
  # Bonding requires setup in /etc/network/interfaces as well.
  #
  if $::is_virtual == 'false' and $::operatingsystem == 'Ubuntu' {
    if $::operatingsystemrelease <= '12.04' {
      package {'ifenslave': ensure => 'present' }
    } else {
      package {'ifenslave-2.6': ensure => 'present' }
    }

    file_line { 'load_module_at_boot':
      filename => '/etc/modules',
      line     => 'bonding',
    }
  }
}

define sunet::snippets::encrypted_swap() {

  package { 'ecryptfs-utils':
    ensure => 'installed'
  } ->

  exec {'sunet_ecryptfs_setup_swap':
    command => '/usr/bin/ecryptfs-setup-swap -f',
    onlyif  => 'grep swap /etc/fstab | grep -ve ^# -e cryptswap | grep -q swap',
  }

}

# Add a user to a group
define sunet::snippets::add_user_to_group($username, $group) {
  exec {"add_user_${username}_to_group_${group}_exec":
    command => "adduser --quiet $username $group",
    path    => ['/usr/local/sbin', '/usr/local/bin', '/usr/sbin', '/usr/bin', '/sbin', '/bin', ],
  }
}

# from http://projects.puppetlabs.com/projects/puppet/wiki/Simple_Text_Patterns/5
define sunet::snippets::file_line($filename, $line, $ensure = 'present') {
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
