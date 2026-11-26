# Host-wide catalog. The converger qualifies all consumers before tagging an image.
class sunet::podman2::lockdown {
  if !$sunet::podman2::lockdown {
    fail('Enroll the host with sunet::podman2(lockdown => true)')
  }
  sunet::enforce_podman2_catalog()
  $base = '/etc/sunet-podman2'
  ensure_packages(['policycoreutils-python-utils', 'python3-setools', 'python3-pyyaml', 'skopeo'])
  file { [$base, '/usr/local/libexec/sunet-podman2', '/var/lib/sunet-podman2']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  ['image.py', 'converge.py', 'guard.py'].each |$script| {
    file { "/usr/local/libexec/sunet-podman2/${script}":
      source => "puppet:///modules/sunet/podman2/${script}",
      owner  => 'root',
      group  => 'root',
      mode   => '0755',
    }
  }
  file { '/etc/systemd/system/sunet-podman2-boot.service':
    source => 'puppet:///modules/sunet/podman2/boot.service',
    notify => Class['sunet::systemd_reload'],
  }
  include sunet::systemd_reload
  service { 'sunet-podman2-boot':
    enable => true, require => File['/etc/systemd/system/sunet-podman2-boot.service'],
  }
  concat { "${base}/catalog":
    owner => 'root',
    group => 'root',
    mode  => '0600',
  }
  concat::fragment { 'podman2 catalog header':
    target  => "${base}/catalog",
    order   => '00',
    content => "\n",
  }
  exec { 'qualify rootless podman2 releases':
    command   => '/usr/local/libexec/sunet-podman2/converge.py apply',
    unless    => '/usr/local/libexec/sunet-podman2/converge.py check',
    timeout   => 1800,
    logoutput => 'on_failure',
    require   => [Concat["${base}/catalog"], Package['skopeo'], Package['python3-setools'],
                  Package['python3-pyyaml'], Package['policycoreutils-python-utils'],
                  File['/usr/local/libexec/sunet-podman2/image.py'],
                  File['/usr/local/libexec/sunet-podman2/guard.py'],
                  File['/usr/local/libexec/sunet-podman2/converge.py'],
                  File['/var/lib/sunet-podman2'], Exec['enable linger for barnbarn']],
  }
}
