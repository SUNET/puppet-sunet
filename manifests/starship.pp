# The coolest prompt
class sunet::starship(
  String $flavor = 'sunet',
  String $version = 'v1.24.1',
  Boolean $check_cosmos = true,
  Boolean $check_haproxy = true,
  Boolean $check_localusers = true,
){

  $host_color = $flavor ? {
    eduid => '#008080',
    default => '#ff6600',
  }

  $config_dir = '/root/.config'
  exec { "sudo-make-me-a-sandwich_${config_dir}":
    command => "/bin/mkdir -p ${config_dir}",
    unless  => "/usr/bin/test -d ${config_dir}",
  }

  file { "${config_dir}/starship.toml":
    ensure  => file,
    mode    => '0644',
    content => template('sunet/starship/starship.toml.erb'),
  }

  exec { 'extract-starship':
    command => "/usr/bin/tar --transform='flags=r;s|starship|starship-${version}|'  -vxzf /etc/puppet/cosmos-modules/sunet/files/starship/starship-x86_64-unknown-linux-musl-${version}.tar.gz -C /usr/local/bin",
    unless  => "/usr/bin/test -x /usr/local/bin/starship-${version}",
  }

  file { '/usr/local/bin/starship':
    ensure => link,
    target => "/usr/local/bin/starship-${version}"
  }

  sunet::snippets::file_line { 'eval-starship_init_bash':
    ensure   => 'present',
    filename => '/root/.bashrc',
    line     => 'eval "$(starship init bash)"',
  }
}
