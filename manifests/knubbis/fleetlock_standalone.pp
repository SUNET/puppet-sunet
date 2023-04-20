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
# @param domain        The domain where the fleetlock server will supply its services
class sunet::knubbis::fleetlock_standalone(
  String        $knubbis_fleetlock_version="v0.0.4",
  String        $etcd_version="v3.5.7",
  String        $cfssl_helper_version="v0.0.1",
  String        $etcdctl_helper_version="v0.0.1",
  String        $domain="",
) {

    # A domain must be supplied by the user
    if $domain != "" {

        $knubbis_fleetlock_standalone_secrets = lookup({ 'name' => 'knubbis::fleetlock_standalone-secrets', 'default_value' => undef })
        $knubbis_fleetlock_secrets = lookup({ 'name' => 'knubbis::fleetlock-secrets', 'default_value' => undef })

        if $knubbis_fleetlock_standalone_secrets {
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
              mode   => '0644',
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
              mode   => '0400',
              owner  => '1000000000',
              group  => '1000000000',
              content => template("sunet/knubbis/fleetlock_standalone/etcd-bootstrap/password-root.erb")
            }

            file { '/opt/knubbis-fleetlock/etcd-bootstrap/password-knubbis-fleetlock':
              ensure => file,
              mode   => '0400',
              owner  => '1000000000',
              group  => '1000000000',
              content => template("sunet/knubbis/fleetlock_standalone/etcd-bootstrap/password-knubbis-fleetlock.erb")
            }

            if $knubbis_fleetlock_secrets {
                file { '/opt/knubbis-fleetlock/conf':
                    ensure => directory,
                    mode   => '0750',
                    owner  => '1000000001',
                    group  => '1000000001',
                }

                file { '/opt/knubbis-fleetlock/conf/knubbis-fleetlock.toml':
                  ensure => file,
                  mode   => '0400',
                  owner  => '1000000001',
                  group  => '1000000001',
                  content => template("sunet/knubbis/fleetlock_standalone/conf/knubbis-fleetlock.toml.erb")
                }

                sunet::docker_compose { 'knubbis-fleetlock_standalone':
                     content          => template('sunet/knubbis/fleetlock_standalone/docker-compose.yml.erb'),
                     service_name     => 'knubbis-fleetlock_standalone',
                     compose_dir      => '/opt',
                     compose_filename => 'docker-compose.yml',
                     description      => 'Standalone knubbis-fleetlock server',
                }
            }
        }
    }
}
