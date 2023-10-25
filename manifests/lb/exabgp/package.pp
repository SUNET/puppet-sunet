# Install exabgp as a package
define sunet::lb::exabgp::package() {
  include sunet::systemd_reload
  ensure_resource('package', 'exabgp', {ensure => 'installed'})

  # Make exabgp run as non-root
  sunet::snippets::file_line { 'exabgp_service_user':
    ensure   => 'uncomment',
    filename => '/lib/systemd/system/exabgp.service',
    line     => 'User=exabgp',
    notify   => [Class['sunet::systemd_reload']],
  }
  sunet::snippets::file_line { 'exabgp_service_group':
    ensure   => 'uncomment',
    filename => '/lib/systemd/system/exabgp.service',
    line     => 'Group=exabgp',
    notify   => [Class['sunet::systemd_reload']],
  }

  service { 'exabgp':
    ensure   => running,
    provider => 'systemd',
    enable   => true,
  }
}
