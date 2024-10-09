# Nvida container toolkit
class sunet::packages::nvidia_cuda_drivers {
  include sunet::packages::curl
  include sunet::packages::linux_headers
  $distro = downcase($facts['os']['distro']['id'])
  $version = delete($facts['os']['distro']['release']['full'], '.')
  $cuda_keyring = 'cuda-keyring_1.0-1_all.deb'
  exec { 'nvidia-cuda-drivers-keyring':
    command => "curl https://developer.download.nvidia.com/compute/cuda/repos/${distro}${version}/x86_64/${cuda_keyring} -o /tmp/${cuda_keyring} && dpkg -i /tmp/${cuda_keyring}",
    unless  => "test -f /tmp/${cuda_keyring}"
  }
  exec { 'nvidia-cuda-drivers-update':
    command => 'apt update',
    require => Exec['nvidia-cuda-drivers-keyring']
  }
  package { 'cuda-drivers':
    ensure   => installed,
    provider => 'apt',
    require  => Exec['nvidia-cuda-drivers-update']
  }
  file_line { 'cuda_env_path':
    path  => '/etc/profile',
    line  => 'PATH=/opt/nvidia/nsight-compute/bin:$PATH',
    match => '^PATH=',
  }
}
