# This puppet manifest is used to install a standalone knubbis-fleetlock node
# running everything on the same machine. It uses self-signed certificates for
# communication between the fleetlock server and the etcd backend and these
# certs are regenerated any time the service starts up.
#
# Client connections use automatically handled acme certs.
#
# The standalone setup offers no redundancy but allows for easy bootstrapping.
#
# The setup is described at https://github.com/SUNET/knubbis-fleetlock/tree/main/docker-compose-sample

# @param knubbis_fleetlock_version The version of the knubbis-fleetlock container to run
# @param etcd_version  The version of the etcd backend container to run
class sunet::knubbis::fleetlock_standalone(
  String        $knubbis_fleetlock_version="v0.0.2",
  String        $etcd_version="v3.5.7",
) {
    file { '/opt/knubbis-fleetlock':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap/bootstrap.sh':
      ensure => file,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      content => template("sunet/knubbis/fleetlock_standalone/cert-bootstrap/bootstrap.sh.erb")
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap/ca.json':
      ensure => file,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      content => template("sunet/knubbis/fleetlock_standalone/cert-bootstrap/ca.json.erb")
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap/csr.json':
      ensure => file,
      mode   => '0644',
      owner  => 'root',
      group  => 'root',
      content => template("sunet/knubbis/fleetlock_standalone/cert-bootstrap/csr.json.erb")
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap-ca':
        ensure => directory,
        mode   => '0755',
        owner  => '1000000000',
        group  => '1000000000',
    }

    file { '/opt/knubbis-fleetlock/cert-bootstrap-etcd':
        ensure => directory,
        mode   => '0755',
        owner  => '1000000000',
        group  => '1000000000',
    }

    file { '/opt/knubbis-fleetlock/etcd-data':
        ensure => directory,
        mode   => '0700',
        owner  => '1000000000',
        group  => '1000000000',
    }

    file { '/opt/knubbis-fleetlock/etcd-bootstrap':
        ensure => directory,
        mode   => '0700',
        owner  => '1000000000',
        group  => '1000000000',
    }

    file { '/opt/knubbis-fleetlock/etcd-bootstrap/bootstrap.sh':
      ensure => file,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
      content => template("sunet/knubbis/fleetlock_standalone/etcd-bootstrap/bootstrap.sh.erb")
    }

    file { '/opt/knubbis-fleetlock/etcd-bootstrap/password-root':
      ensure => file,
      mode   => '0750',
      owner  => '1000000000',
      group  => '1000000000',
      content => template("sunet/knubbis/fleetlock_standalone/etcd-bootstrap/password-root.erb")
    }

    file { '/opt/knubbis-fleetlock/etcd-bootstrap/password-knubbis-fleetlock':
      ensure => file,
      mode   => '0750',
      owner  => '1000000000',
      group  => '1000000000',
      content => template("sunet/knubbis/fleetlock_standalone/etcd-bootstrap/password-knubbis-fleetlock.erb")
    }
}
