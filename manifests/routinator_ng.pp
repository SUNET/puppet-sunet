class sunet::routinator_ng() {
      exec {"Add package repo":
	    command => "echo deb [arch=amd64] https://packages.nlnetlabs.nl/linux/ubuntu/ `lsb_release -cs` main > /etc/apt/sources.list.d/routinator.list",
	    unless => "test -f /etc/apt/sources.list.d/routinator.list"
      }

      exec {"Add package key":
	   command => "wget -qO- https://packages.nlnetlabs.nl/aptkey.asc | sudo apt-key add -"
      }

      exec {"Update package repo":
	   command => "apt update"
      }

      package {'routinator': ensure => installed }

      exec {"Configure Routinator":
	   command => "routinator-init --accept-arin-rpa",
	   unless => "test -d /var/lib/routinator/tals"
      }

      service { "routinator": ensure => 'running', enable => true, }
}
