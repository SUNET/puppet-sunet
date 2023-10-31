# Nvida container toolkit
class sunet::packages::nvidia_container_toolkit {
    include sunet::packages::curl
    include sunet::packages::gpg
    exec { 'nvidia-container-toolkit-keyring':
      command => 'curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg',
      unless  => 'test -f /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg'
    }
    exec { 'nvidia-container-toolkit-repo':
      command => 'curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed "s_deb https://_deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://_g" > /etc/apt/sources.list.d/nvidia-container-toolkit.list',
      unless  => 'test -f /etc/apt/sources.list.d/nvidia-container-toolkit.list'
    }
    exec { 'nvidia-container-toolkit-update':
      command => 'apt update',
      require => Exec['nvidia-container-toolkit-keyring', 'nvidia-container-toolkit-repo']
    }
    package { 'nvidia-container-toolkit':
      ensure   => installed,
      provider => 'apt',
      require  => Exec['nvidia-container-toolkit-update']
    }
}
