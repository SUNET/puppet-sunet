# Set up certificate bundles in close to arbitrary forms
define sunet::misc::certbundle(
  Optional[String] $hiera_key = undef,
  Optional[String] $keyfile   = undef,
  String           $group     = 'root',
  Array[String]    $bundle = [],
) {
  if $hiera_key != undef {
    $_bundle_key_a = filter($bundle) | $this | { $this =~ /^key=/ }
    $_bundle_key = $_bundle_key_a ? {
      [] => undef,
      default => $_bundle_key_a[0][4,-1],
    }

    $_keyfile1 = pick_default($keyfile, $_bundle_key)

    if $_keyfile1 =~ String[1] {
      # Use path /etc/ssl/private/ if keyfile was specified without directory
      $_keyfile = dirname($_keyfile1) ? {
        '.'     => sprintf('/etc/ssl/private/%s', $_keyfile1),
        default => $_keyfile1,
      }

      #notice("Creating keyfile ${keyfile}")
      sunet::misc::create_key_file { $_keyfile:
        hiera_key => $hiera_key,
        group     => $group,
      }
      $req = [Sunet::Misc::Create_key_file[$_keyfile]]
      if $group != 'root' {
        # /etc/ssl/private is owned by group ssl-cert and not world-accessible
        # XXX this makes the assumption that there is a user named the same as the $group
        ensure_resource( 'sunet::snippets::add_user_to_group', "${group}_ssl-cert", {
          username => $group,
          group    => 'ssl-cert',
          })
      }
    } else {
      $req = []
    }
  } else {
    $req = []
  }

  if $bundle =~ Array[String, 1] {
    ensure_resource('file', '/usr/local/sbin/cert-bundler', {
      ensure  => file,
      content => template('sunet/misc/cert-bundler.erb'),
      mode    => '0755'
      })

    $bundle_args = join($bundle, ' ')
    #notice("Creating file with command /usr/local/sbin/cert-bundler --syslog --group ${group} $bundle_args")
    ensure_resource('exec', "create_${name}", {
      'command' => "/usr/local/sbin/cert-bundler --syslog --group ${group} ${bundle_args}",
      'unless'  => "/usr/local/sbin/cert-bundler --unless --group ${group} ${bundle_args}",
      'require' => $req,
      'returns' => [0, 1],
      })
  }
}
