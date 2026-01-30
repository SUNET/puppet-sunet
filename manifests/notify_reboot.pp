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

    $slack_url = lookup('notity_reboot_slack_url', String, undef, '')

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
