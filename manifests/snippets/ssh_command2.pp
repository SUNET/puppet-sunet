# For hosts using sunet::ssh_config.
define sunet::snippets::ssh_command2(
  String $ssh_key,
  String $ssh_key_type,
  String $command,
  String $user         = 'root',
  Boolean $manage_user = false,
) {
  $safe_name = regsubst($name, '[^0-9A-Za-z.\-]', '-', 'G')

  if ($manage_user) {
    ensure_resource('group', $user)
    sunet::system_user { $user:
      username => $user,
      group    => $user,
    }
  }

  $database = { $safe_name => {
    'key' => $ssh_key,
    'type' => $ssh_key_type,
    'options' => join([
      "command=\"${command}\"",
      'no-agent-forwarding',
      'no-port-forwarding',
      'no-pty',
      'no-user-rc',
      'no-X11-forwarding'
      ], ','),
    }}

  $config = { $user => [$safe_name]}
  sunet::ssh_keys { $name:
    config   => $config,
    database => $database,
    order    => '200',
  }
}
