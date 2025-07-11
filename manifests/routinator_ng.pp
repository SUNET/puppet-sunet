# Routinator from NLnetLabs
class sunet::routinator_ng() {
      exec {'Add package repo':
      command => 'echo deb [arch=amd64] https://packages.nlnetlabs.nl/linux/ubuntu/ `lsb_release -cs` main > /etc/apt/sources.list.d/routinator.list',
      unless  => 'test -f /etc/apt/sources.list.d/routinator.list'
      }

      exec {'Add package key':
    command => 'wget -qO- https://packages.nlnetlabs.nl/aptkey.asc | sudo apt-key add -'
      }

      exec {'Update package repo':
    command => 'apt update'
      }

      package {'routinator': ensure => installed }

      exec {'Configure Routinator':
    command => 'routinator-init --accept-arin-rpa',
    unless  => 'test -d /var/lib/routinator/tals'
      }

      exec {'Change addresses to listen to':
          command => "sed -i 's/127.0.0.1/0.0.0.0/g' /etc/routinator/routinator.conf"
      }

      service { 'routinator': ensure => 'running', enable => true, }

      sunet::misc::ufw_allow { 'rpki-rtr-fw':
        from  => '130.242.1.0/24',
        port  => '3323',
        proto => 'tcp',
      }
}
