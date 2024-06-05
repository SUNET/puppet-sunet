# Set up SSH authorized keys
define sunet::ssh_keys(
  Hash[String, Array[String]]  $config,  # mapping of host username (e.g. 'root') to a list of ssh keys
  Optional[Hash[String, Hash]] $database = undef,  # can be supplied instead of read from Hiera
  String $key_database_name = 'sunet_ssh_keys',
  String $order             = '100',
) {
  # This class loads a big database of SSH keys from one place in Hiera, and then a list of keys to add to
  # users on a host from another place. Example:
  #
  # sunet_ssh_keys:
  #   'ft+505152DD':
  #      key    : 'AAAA...'
  #   'nobody@sunet.se':
  #      key    : 'AAAA...'
  #
  # sunetops_ssh_keys:
  #   'root':
  #     - 'ft+505152DD'
  #
  # A host in the sunetops class might load the ACL sunetops_ssh_keys and invoke this class,
  # resulting in the file /root/.ssh/authorized_keys to be replaced with only the key
  # 'ft+505152DD'. Some other group of hosts might have another ACL adding both
  # the SSH keys on those machines.
  #
  if $database {
    $keydb = $database
  } else {
    $keydb = lookup($key_database_name, undef, undef, undef)
  }
  if $keydb =~ Hash[String, Hash] {
    each ($config) | String $username, Array[String] $keys | {
      $authorized_keys = map(sort($keys)) | String $keyname | {
        if $keyname in $keydb {
          $_name = pick($keydb[$keyname]['name'], $keyname)
          $_type = pick($keydb[$keyname]['type'], 'ssh-rsa')
          $_key = $keydb[$keyname]['key']
          if 'options' in $keydb[$keyname] {
            sprintf('%s %s %s %s', $keydb[$keyname]['options'], $_type, $_key, $_name)
          } else {
            sprintf('%s %s %s', $_type, $_key, $_name)
          }
        } else {
          # Must prefix this warning with # because it will end up being collected by the 'map' and put in the authorized_keys file
          warning("# No SSH key with name ${keyname} found in key database (${key_database_name})")
        }
      }

      if ($authorized_keys) {
        $sorted_keys = join($authorized_keys, "\n#\n")
        # Can't see a way to get the user's actual home directory in Puppet without creating
        # a fact... Go with an assumption for now.
        $homedir = $username ? {
          'root'  => '/root',
          default => "/home/${username}",
        }
        $ssh_fn = "${homedir}/.ssh/authorized_keys"
        ensure_resource('file', "${homedir}/.ssh", { ensure => 'directory', })
        # Clean away file used using development of this class. Can be safely removed in a day or so.
        ensure_resource('file', "${ssh_fn}.test", { ensure => 'absent', })

        ensure_resource('concat', $ssh_fn, {
          owner => 'root',  # puppet runs as root, so root owns this now.
          group => $username,
          mode  => '0440',
          })

        ensure_resource('concat::fragment', "${ssh_fn}_header", {
          target  => $ssh_fn,
          order   => '01',
          content => "# This file is generated using Puppet. Any changes will be lost.\n#\n",
          })

        concat::fragment { "${ssh_fn}_${name}_keys":
          target  => $ssh_fn,
          order   => $order,
          content => "#\n# Keys from ${name}:\n#\n${sorted_keys}\n",
        }
      } else {
        warning("Not writing an empty fragment to ${ssh_fn}")
      }
    }
  } else {
    warning("SUNET ssh key database (${key_database_name}) not found (or malformed) in Hiera")
  }
}
