# Create configuration file readable by user (owned by root). Default mode 0640.
define sunet::misc::create_cfgfile(
  String  $content,
  String  $group,
  String  $mode    = '0640',
  Boolean $force   = false,
{
  $req_group = $group ? {
    # groups not created in Puppet, so can't require them
    'root'     => [],
    'www-data' => [],
    default    => Group[$group],
  }

  file { $name :
    ensure  => 'file',
    mode    => $mode,
    group   => $group,
    content => $content,
    require => $req_group,
    force   => $force,
  }
}
