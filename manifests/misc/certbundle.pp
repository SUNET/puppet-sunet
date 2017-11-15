# Set up certificate bundles in close to arbitrary forms
define sunet::misc::certbundle(
  Array[String]    $script,
  Optional[String] $hiera_key,
  String           $group     = 'root',
) {
  $_key = filter($script) | $this | { $this =~ /^key=/ }
  $keyfile = $_key ? {
    [] => undef,
    default => $_key[0][4,-1],
  }

  if $keyfile {
    #notice("Creating keyfile ${keyfile}")
    sunet::misc::create_key_file { $keyfile:
      hiera_key => $hiera_key,
      group     => $group,
    }
    $req = [Sunet::Misc::Create_key_file[$keyfile]]
    if $group != 'root' {
      # /etc/ssl/private is owned by group ssl-cert and not world-accessible
      # XXX this makes the assumption that there is a user named the same as the $group
      sunet::snippets::add_user_to_group { "${group}_ssl-cert":
        username => $group,
        group    => 'ssl-cert',
      }
    }
  } else {
    $req = []
  }

  if $script =~ Array[String, 1] {
    ensure_resource('file', '/usr/local/sbin/cert-bundler', {
      ensure  => file,
      content => template('sunet/misc/cert-bundler.erb'),
      mode    => '0755'
      })

    $script_args = join($script, ' ')
    #notice("Creating ${outfile} with command /usr/local/sbin/cert-bundler --syslog $script_args")
    ensure_resource('exec', "create_${name}", {
      'command' => "/usr/local/sbin/cert-bundler --syslog ${script_args}",
      'unless'  => "/usr/local/sbin/cert-bundler --unless ${script_args}",
      'require' => $req,
      'returns' => [0, 1],
      })
  }
}
