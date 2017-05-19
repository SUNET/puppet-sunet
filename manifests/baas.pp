# So this is the chaotic install instruct for the uber chaotic BaaS... 
# 1. First of all, create a node in the BaaS API and jot down the password.
# 2. Use edit-secrets to give the password to the node BEFORE you run this, 
#    use the syntax "baas_password: XXXXXX" in edit-secrets.
# 3. Call upon this module with the nodename as input string.
# 4. PRAY!
class sunet::baas(  
   String $nodename,
   $src_url="https://api.cloud.ipnett.se/dist/tsm/mirror/maintenance/storage/tivoli-storage-management/maintenance/client/v7r1/Linux/LinuxX86_DEB/BA/v712/7.1.2.0-TIV-TSMBAC-LinuxX86_DEB.tar",
) {

  $baas_password = hiera('baas_password', 'NOT_SET_IN_HIERA')

  if $baas_password != 'NOT_SET_IN_HIERA' and $nodename {
    sunet::remote_file { "/tmp/baas/baas.tar":
       remote_location => $src_url,
       mode            => "0600"
    } ->
    exec {"unpack BaaS source code":
       command => "tar xvf /tmp/baas/baas.tar -C /tmp/baas",
    } ->
    exec {"Install the debs from BaaS 1":
       command => "dpkg -i /tmp/baas/gskcrypt64*deb /tmp/baas/gskssl64*deb",
    } ->
    exec {"Install the debs from BaaS 2":
       command => "dpkg -i /tmp/baas/tivsm-api64*deb",
    } ->
    exec {"Install the debs from BaaS 3":
       command => "dpkg -i /tmp/baas/tivsm-ba.*deb",
    } ->
    exec {"Install the debs from BaaS 4":
       command => "dpkg -i /tmp/baas/tivsm-bacit*deb",
    }
 
    file { "/opt/tivoli/tsm/client/ba/bin/dsm.sys":
       ensure  => "file",
       content => template("sunet/baas/dsm_sys.erb")
    }
    file { "/opt/tivoli/tsm/client/ba/bin/dsm.opt":
       ensure  => "file",
       content => template("sunet/baas/dsm_opt.erb")
    }
  }


    # IBM...... so this keystore contains a password protected public CA certificate
    sunet::remote_file { "/tmp/baas/IPnett-Cloud-Root-CA.sh":
       remote_location => "https://raw.githubusercontent.com/safespring/cloud-BaaS/master/pki/IPnett-Cloud-Root-CA.sh",
       mode            => "755",
    }
    sunet::remote_file { "/tmp/baas/IPnett-Cloud-Root-CA.pem":
       remote_location => "https://raw.githubusercontent.com/safespring/cloud-BaaS/master/pki/IPnett-Cloud-Root-CA.pem",
       mode            => "440"
    }
    exec {"install CA cert to keystore":
       command => "/bin/sh /tmp/baas/IPnett-Cloud-Root-CA.sh",
       unless  => "test -f /opt/tivoli/tsm/client/ba/bin/dsmcert.kdb",
    }
}
