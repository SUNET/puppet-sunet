define sunet::pollinate($device = "/dev/random") {
   if ($::operatingsystem == 'Ubuntu' and $::operatingsystemrelease == '12.04') {
      apt::ppa {'ppa:ndn/pollen': }
   } else {
      apt::ppa {'ppa:ndn/pollen': ensure => absent }
   }
   package {"pollinate": ensure => latest } ->
   file { "/etc/default/pollinate": 
      ensure => file,
      owner  => root,
      group  => root,
      content => template("sunet/pollen/pollinate.erb")
   } ->
   cron {"repollinate": 
      command => "pollinate -r",
      user    => root,
      hour    => "*",
      minute  => "0"
   }
}
