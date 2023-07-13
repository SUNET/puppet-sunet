# So this is the chaotic install instruct for the uber chaotic BaaS...
#
#   1. First of all, create a node in the BaaS API and jot down (copy) the password.
#   2. Use edit-secrets to give the password to the node BEFORE you run this,
#      use the syntax "baas_password: XXXXXX" in edit-secrets.
#   3. Create a list in hiera with the directories to backup, similar to this:
#      dirs_to_backup:
#         - /var/log/
#         - /opt/goodstuff/
#      NOTE: These dirs_to_backup *MUST* have a trailing slash or they wont be backed!!!
#   4. Call upon this module with the nodename, remember default also backs up subdirs.
class sunet::baas_repo(
  String $nodename,
  $extra='-subdir=yes',
  $repo='https://repo.cloud.ipnett.com/debtest/',
  $gpg_key='https://repo.cloud.ipnett.com/debtest/pubkey.gpg',
  $gpg_file='/root/safespring_pubkey.gpg',
  $cron=false,
) {

  # Both these MUST be set properly in hiera to continue
  $baas_password = safe_hiera('baas_password')
  $backup_dirs_not_empty = safe_hiera('dirs_to_backup')

  if $baas_password != 'NOT_SET_IN_HIERA' and $backup_dirs_not_empty != 'NOT_SET_IN_HIERA' and $nodename {
    # These 2 rows to get a single string of all directories to backup + extras (flags normally)
    $dirs_to_backup_array = concat(safe_hiera('dirs_to_backup'), $extra)
    $dirs_to_backup = join($dirs_to_backup_array, ' ')

    # This is a control file used to skip these semi-heavy installation steps
    $control_file='/opt/tivoli/tsm/install_complete.txt'

    # Grab PGP key from Safespring and add it & repo to sources
    sunet::remote_file { $gpg_file:
      remote_location => $gpg_key,
      mode            => '0600',
    }
    -> exec {'Add Safesprings key to chain & repo':
      command => "apt-key add < ${gpg_file} && gpg --import ${gpg_file}",
      unless  => "test -f ${control_file}",
    }
    -> exec {'Add Safesprings repository to sources and update':
      command => "add-apt-repository ${repo} && apt-get update",
      unless  => "test -f ${control_file}",
    }

    # Time to install the stuff from Safesprings repository!
    exec {'Install TSM stuff from Safespring':
      command => "apt-get install safespring-baas-setup expect && touch ${control_file}",
    }

    # These will probably never change but you never know so outside the chain :P
    file { '/opt/tivoli/tsm/client/ba/bin/dsm.sys':
      ensure  => 'file',
      content => template('sunet/baas/dsm_sys.erb')
    }
    file { '/opt/tivoli/tsm/client/ba/bin/dsm.opt':
      ensure  => 'file',
      content => template('sunet/baas/dsm_opt.erb')
    }
    file { '/usr/local/bin/bootstrap-baas':
      ensure  => 'file',
      mode    => '0755',
      content => template('sunet/baas/bootstrap-baas')
    }

  }

  if $cron {
  # FIXME: Add pass-through to be able to configure time of cronjob
    sunet::scriptherder::cronjob { 'backup_to_baas':
      cmd           => "/usr/bin/dsmc incremental ${dirs_to_backup}",
      minute        => '30',
      hour          => '4',
      ok_criteria   => ['exit_status=0', 'max_age=25h'],
      warn_criteria => ['exit_status=0', 'max_age=49h'],
    }
  }

  # Because TSM we created an expect-script to get rid of human clickety-click needs
  exec {'Initiate the new node in BaaS':
    command => "/usr/local/bin/bootstrap-baas ${nodename} ${baas_password}",
    unless  => 'test -f /etc/adsm/TSM.KBD',
  }

}
