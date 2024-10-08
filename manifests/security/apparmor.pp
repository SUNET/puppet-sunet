# Since Apparmor is not enabled by default on Debian 9 we need to
# change the boot parameters for the kernel to turn it on.
# Debian 10 will, according to the current information, have
# Apparmor enabled by default so this might not be needed in the future.
# apparmor-utils is installed so we can test and debug profiles.
class sunet::security::apparmor () {
  package { 'apparmor-utils': ensure => latest }
  if $facts['os']['name'] == 'Debian' and $facts['os']['release']['major'] == '9' {
    exec { 'enable_apparmor_on_Debian_9':
      command => 'bash -c \'source /etc/default/grub && sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT\"' +
      '/GRUB_CMDLINE_LINUX_DEFAULT=\"$GRUB_CMDLINE_LINUX_DEFAULT apparmor=1 security=apparmor\"/g" /etc/default/grub && update-grub\'',
      unless  => 'grep -q "apparmor" /etc/default/grub',
    }
  }
}
