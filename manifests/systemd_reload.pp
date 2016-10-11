# Reload systemd service definitions.
# Refreshonly means this target has to be notified by other targets.
class sunet::systemd_reload {
  exec { 'sunet_systemd_reload':
    command     => '/bin/systemctl daemon-reload',
    refreshonly => true,
  }
}
