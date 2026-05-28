# Notify reboot
class sunet::notify_reboot(
) {

    file { '/etc/molly-guard/run.d/99-notify-reboot':
        ensure  => file,
        mode    => '0755',
        owner   => 'root',
        group   => 'root',
        content => file('sunet/notify-reboot/99-notify-reboot'),
    }

    if (lookup('cosmos_fleetlock_config', Variant[Hash, Undef], undef, undef)) {

      ensure_resource(
        'sunet::misc::create_dir',
        '/etc/sunet-machine-healthy/health-checks.d',
        {
          owner => 'root',
          group => 'root',
          mode  => '0750',
        }
      )

      file { '/etc/sunet-machine-healthy/health-checks.d/99-notify-unlock.check':
          ensure  => file,
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
          content => file('sunet/notify-reboot/99-notify-unlock.check'),
      }

    }

    $slack_url = lookup('notity_reboot_slack_url', Variant[String, Undef], undef, undef)

    if ($slack_url) {
      file { '/etc/sunet-notify-reboot':
          ensure  => file,
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
          content => template('sunet/notify-reboot/sunet-notify-reboot.erb'),
      }

    } else {
      warning('"notity_reboot_slack_url" not configured - no notifications will be sent!')
    }
}
