class sunet::ntp {
   package { 'ntp': ensure => "latest" }
   service { 'ntp':
      name       => 'ntp',
      ensure     => running,
      enable     => true,
      hasrestart => true,
      require => Package['ntp'],
   }
}
