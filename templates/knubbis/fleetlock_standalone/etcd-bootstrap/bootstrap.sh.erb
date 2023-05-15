#!/busybox/sh

# This script is used to enable authentication and set up permissions for the
# knubbis-fleetlock service in etcd.

# When running this for the first time the authentication will not be
# enabled in etcd and that will lead to errors in the logs like "etcdserver:
# authentication is not enabled" when running commands. The actions will still
# be carried out anyway so it seems easier to just always include
# username/password than trying to figure out if auth is enabled.

base_cmd="etcdctl --cacert=/cert-bootstrap-ca/ca.pem --endpoints=https://etcd:2379 --cert=/cert-bootstrap-client-root/root.pem --key=/cert-bootstrap-client-root/root-key.pem"

# wait for etcd container to be alive
while true; do
    if $base_cmd endpoint health; then
        break
    fi
    sleep 1
done

# If auth is not enabled this is our hint to set things up
if $base_cmd auth status | grep -q '^Authentication Status: false$'; then

    # Add 'root' user, required for enabling auth
    if ! $base_cmd user list | grep -q '^root$'; then
        $base_cmd user add root --no-password
        $base_cmd user grant-role root root
    fi

    # Add 'knubbis-fleetlock' user, used by the service when talking to the backend
    if ! $base_cmd user list | grep -q '^knubbis-fleetlock$'; then
        $base_cmd user add knubbis-fleetlock --no-password
    fi

    # Add role with permissions and assign it to knubbis-fleetlock user
    if ! $base_cmd role list | grep -q '^knubbis-fleetlock-role$'; then
        $base_cmd role add knubbis-fleetlock-role
        $base_cmd role grant-permission --prefix=true knubbis-fleetlock-role readwrite se.sunet.knubbis/fleetlock/config/
        $base_cmd role grant-permission --prefix=true knubbis-fleetlock-role readwrite se.sunet.knubbis/fleetlock/groups/
        $base_cmd role grant-permission --prefix=true knubbis-fleetlock-role readwrite se.sunet.knubbis/certmagic/
        $base_cmd user grant-role knubbis-fleetlock knubbis-fleetlock-role
    fi

    # Finally, actually enable the authentication
    $base_cmd auth enable
fi
