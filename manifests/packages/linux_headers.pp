# Nvida container toolkit
class sunet::packages::linux_headers {
    package { "linux-headers-${facts['kernel_release']}":
      ensure   => installed,
      provider => 'apt',
    }
}
