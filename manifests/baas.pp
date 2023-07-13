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
#   4. Call upon this module with the nodename, default also backs up subdirs.
class sunet::baas(
  String $nodename,
  $extra='-subdir=yes',
  $src_url='https://api.cloud.ipnett.se/dist/tsm/mirror/maintenance/storage/tivoli-storage-management/maintenance/client/v7r1/Linux/LinuxX86_DEB/BA/v712/7.1.2.0-TIV-TSMBAC-LinuxX86_DEB.tar',
  $cron=false,
) {

  # Both these MUST be set properly in hiera to continue
  $baas_password = hiera('baas_password', 'NOT_SET_IN_HIERA')
  $backup_dirs_not_empty = hiera('dirs_to_backup','NOT_SET_IN_HIERA')

  # This is silly but somehow you must know if BaaS has been installed already, if not you may break an already existing installation.
  $control_file='/opt/tivoli/tsm/client/install_successful'

  if $baas_password != 'NOT_SET_IN_HIERA' and $backup_dirs_not_empty != 'NOT_SET_IN_HIERA' and $nodename {
    # These 2 rows to get a single string of all directories to backup + extras (flags normally)
    $dirs_to_backup_array = concat(hiera('dirs_to_backup','NOT_SET_IN_HIERA'), $extra)
    $dirs_to_backup = join($dirs_to_backup_array, ' ')

    exec {'Create temp directory':
      command => '/bin/mkdir -p /tmp/baas',
      unless  => "test -f ${control_file}",
    }

    sunet::remote_file { '/tmp/baas/baas.tar':
      remote_location => $src_url,
      mode            => '0600'
    }
    -> exec {'Unpack BaaS source code':
      command => 'tar xvf /tmp/baas/baas.tar -C /tmp/baas',
      unless  => "test -f ${control_file}",
    }
    -> exec {'Install the debs from BaaS 1':
      command => 'dpkg -i /tmp/baas/gskcrypt64*deb /tmp/baas/gskssl64*deb',
      unless  => "test -f ${control_file}",
    }
    -> exec {'Install the debs from BaaS 2':
      command => 'dpkg -i /tmp/baas/tivsm-api64*deb',
      unless  => "test -f ${control_file}",
    }
    -> exec {'Install the debs from BaaS 3':
      command => 'dpkg -i /tmp/baas/tivsm-ba.*deb',
      unless  => "test -f ${control_file}",
    }
    -> exec {'Install the debs from BaaS 4':
      command => 'dpkg -i /tmp/baas/tivsm-bacit*deb',
      unless  => "test -f ${control_file}",
    }
    # IBM...... so this keystore contains a password protected(!) public CA certificate
    -> sunet::remote_file { '/tmp/baas/IPnett-Cloud-Root-CA.sh':
      remote_location => 'https://raw.githubusercontent.com/safespring/cloud-BaaS/master/pki/IPnett-Cloud-Root-CA.sh',
      mode            => '755',
    }
    -> sunet::remote_file { '/tmp/baas/IPnett-Cloud-Root-CA.pem':
      remote_location => 'https://raw.githubusercontent.com/safespring/cloud-BaaS/master/pki/IPnett-Cloud-Root-CA.pem',
      mode            => '440'
    }
    -> exec {'Install CA cert to keystore':
      command => "/bin/sh /tmp/baas/IPnett-Cloud-Root-CA.sh && touch ${control_file}",
      unless  => 'test -f /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb',
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

  # FIXME: This doesnt currently work because TSM requires a human to press enter to initiate a new host with dsmc
  exec {'Initiate the new node in BaaS':
    command => "dsmc query session -password=${baas_password}",
    unless  => 'test -f /etc/adsm/TSM.PWD',
  }

}
