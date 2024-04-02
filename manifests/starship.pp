# The coolest prompt
class sunet::starship(
  String $flavor = 'sunet',
){

  $prompt_color = $flavor ? {
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
}
