# This puppet manifest is used to install the client side stuff needed to use
# the Safespring Backup 2.0 system (based on IBM Spectrum Protect,
# previously IBM Tivoli Storage Manager (TSM)):
# https://www.safespring.com/en/services/backup/
#
# The manifest is based on sunet::baas, sunet::baas_repo and the derivative
# nunoc::baas(_repo) and cnaas:baas(_repo) manifests.
#
# The "_repo" manifests depend on debian packages built by safespring, but this
# is not done for Backup 2.0, so we automate the installation via some custom
# tooling instead.
#
# The previous generation also depended on cron to run backups, sunet::baas2
# expects scheduling to be handled centrally via the IBM server.
#
# Steps needed to initialize backup:
#   1. Create a node in the BaaS 2.0 system and save the node password.
#   2. Use edit-secrets to give the password to the node BEFORE you run this,
#      use the syntax "baas_password: XXXXXX" in edit-secrets.
#   3. Call upon this module with the nodename, default also backs up subdirs.
#

# @param nodename  The nodename registered in the IBM system for this server
# @param version   The version of the client to install
class sunet::baas2(
   String $nodename="",
   String $version="8.1.15.2",
) {

  # MUST be set properly in hiera to continue
  $baas_password = hiera('baas_password', 'NOT_SET_IN_HIERA')

  if $nodename and $baas_password != 'NOT_SET_IN_HIERA' {

    file { "/usr/local/sbin/sunet-bootstrap-baas2":
       ensure  => 'file',
       mode    => '0755',
       owner   => 'root',
       content => file('sunet/baas2/sunet-bootstrap-baas2')
    }

    # Make sure the requested version is installed
    exec { "/usr/local/sbin/sunet-bootstrap-baas2 --version=$version":
    }

    # Install the configuration files
    file { "/opt/tivoli/tsm/client/ba/bin/dsm.sys":
       ensure  => "file",
       content => template("sunet/baas2/dsm_sys.erb")
    }
    file { "/opt/tivoli/tsm/client/ba/bin/dsm.opt":
       ensure  => "file",
       content => template("sunet/baas2/dsm_opt.erb")
    }

  }

  # FIXME: This doesnt currently work because TSM requires a human to press enter to initiate a new host with dsmc
  exec {"Initiate the new node in BaaS":
     command => "dsmc query session -password=$baas_password",
     unless  => "test -f /etc/adsm/TSM.PWD",
  }

}
