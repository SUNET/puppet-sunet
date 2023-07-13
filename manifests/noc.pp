# Class for allowing NOC staff to do specific predefined tasks on servers
class sunet::noc(
  Boolean $allow_reboot = true,
) {
  $noc_ssh_keys = lookup('noc_ssh_keys', undef, undef, undef)
  # If we have Authorized keys for NOC staff, we create a user, 
  # add ssh keys there and allow them to run select commands
  if is_hash($noc_ssh_keys) {
    sunet::misc::system_user { 'noc':
      username   => 'noc',
      group      => 'noc',
      shell      => '/bin/bash',
      managehome => true
    }

    sunet::ssh_keys { 'noc_ssh_keys':
      config   => { 'noc' => keys($noc_ssh_keys) },
      database => $noc_ssh_keys,
    }
    # This sudoers rule will allow noc user to run commands without password if they
    # are in /usr/local/bin and start with sunet_noc_. This is safe because only root 
    # can put files in /usr/local/bin, however if you have granted a non privileged user
    # write on /usr/local/bin/ you should NOT use this class (Also, why are you doing that?).
    #
    # This means that you (you as in your root user) can drop commands in /usr/local/bin 
    # from another class, and if they start with sunet_noc_, then the noc user can execute
    # them as root. 
    file { '/etc/sudoers.d/99-noc-commands':
      ensure  => file,
      content => "noc ALL=(root) NOPASSWD: ^/usr/local/bin/sunet_noc_[a-zA-Z0-9]+$\n",
      mode    => '0440',
      owner   => 'root',
      group   => 'root',
    }
    if $allow_reboot {
      file { '/usr/local/bin/sunet_noc_reboot':
        ensure  => file,
        content => "#!/bin/bash\n/usr/sbin/reboot\n",
        mode    => '0750',
        owner   => 'root',
        group   => 'root',
      }
    }
  }
  # If the keys are not there we will not allow the NOC user to log in and do some clean up
  else {
    sunet::misc::system_user {'noc':
      ensure     => absent,
    }
    file { '/etc/sudoers.d/99-noc-commands':
      ensure  => absent,
    }
    file { '/home/noc/.ssh/authorized_keys':
      ensure  => absent,
    }
    file { '/usr/local/bin/sunet_noc_reboot':
      ensure  => absent,
    }
  }
  unless $allow_reboot {
    file { '/usr/local/bin/sunet_noc_reboot':
      ensure  => absent,
    }
  }
}
