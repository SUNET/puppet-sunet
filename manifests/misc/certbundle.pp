# Set up certificate bundles in close to arbitrary forms
# @param hiera_key  If provided, write the Hiera contents to $keyfile
# @param keyfile    If provided, write the Hiera contents of $hiera_key to this file
# @param group      The group that should own the generated files
# @param bundle     An array of strings that are passed to cert-bundler.
#
# Example bundle:
#
#   bundle => [
#     "cert=${_cert_name}.pem",
#     'chain=infra.crt',
#     "out=/etc/ssl/${_cert_name}_bundle.pem",
#   ],
#
#  This will concatenate the certificate and the chain file into a bundle file, in that order.
#
define sunet::misc::certbundle (
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
      ensure_resource('sunet::misc::create_key_file', $_keyfile, {
          hiera_key => $hiera_key,
          group     => $group,
      })
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
        mode    => '0755',
    })

    $bundle_args = join($bundle, ' ')
    #notice("Creating file with command /usr/local/sbin/cert-bundler --syslog --group ${group} $bundle_args")
    ensure_resource('exec', "create_${name}", {
        'command' => "/usr/local/sbin/cert-bundler --syslog --group ${group} ${bundle_args}",
        'unless'  => "/usr/local/sbin/cert-bundler --unless --group ${group} ${bundle_args}",
        'require' => $req,
        'returns' => [0, 1],
    })

    # Get the "out=" line from the bundle array
    $_bundle_out_a = filter($bundle) | $this | { $this =~ /^out=/ }
    $_bundle_out_b = $_bundle_out_a ? {
      [] => undef,
      default => $_bundle_out_a[0][4,-1],
    }

    # Use path /etc/ssl/ if outfile was specified without an absolute path
    $_bundle_out = $_bundle_out_b ? {
      /^\/.*/ => $_bundle_out_b,
      default => sprintf('/etc/ssl/%s', $_bundle_out_b),
    }

    if $_bundle_out {
      # Create a subscribable resource for the generated bundle file, allowing service restarting when the
      # bundle file changes (i.e. when the input files change).
      file { $_bundle_out:
        audit     => 'content',
        show_diff => false,  # don't show diff as there might be a secret key in there
      }
    }
  }
}
