# Binary for check_gpg_keys
class sunet::nagios::nrpe_check_gpg_keys_bin (
) {
    file { '/usr/lib/nagios/plugins/check_gpg_keys':
      ensure  => 'file',
      mode    => '0755',
      owner   => 'root',
      content => file('sunet/nagios/check_gpg_keys.sh')
    }
}
