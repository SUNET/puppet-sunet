# Give nrpe_t read access to Scriptherder's private job records on EL.
class sunet::scriptherder::selinux {
  $policy = file('sunet/scriptherder/sunet_scriptherder.cil')
  $digest = sha256($policy)
  $path = '/usr/share/selinux/packages/sunet_scriptherder.cil'

  file { $path:
    ensure  => file,
    mode    => '0644',
    content => $policy,
  }
  exec { 'install sunet_scriptherder SELinux module':
    command => "/usr/sbin/semodule -X 400 -i ${path}",
    unless  => "/usr/sbin/semodule -lfull -m | /usr/bin/grep -Eq '^400 +sunet_scriptherder +cil +sha256:${digest} *$'",
    require => [File[$path], Package['nrpe']],
    notify  => Exec['label existing Scriptherder records'],
  }

  # New records inherit the cache directory type. Apply the file context to
  # existing records when installing or updating the policy.
  exec { 'label existing Scriptherder records':
    command     => '/usr/sbin/restorecon -Rx /var/cache/scriptherder',
    onlyif      => '/usr/bin/test -d /var/cache/scriptherder',
    refreshonly => true,
  }
  File <| title == '/var/cache/scriptherder' |> ~> Exec['label existing Scriptherder records']
}
