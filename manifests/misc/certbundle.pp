# Set up certificate bundles in close to arbitrary forms
define sunet::misc::certbundle(
  Array[String]    $script,
  Optional[String] $hiera_key,
  String           $group     = 'root',
) {

  $_key = filter($script) | $this | { $this =~ /^key=/ }
  $keyfile = $_key ? {
    [] => undef,
    default => $_key[0][4,-1],
  }

  if $keyfile {
    #notice("Creating keyfile ${keyfile}")
    sunet::misc::create_key_file { $keyfile:
      hiera_key => $hiera_key,
      group     => $group,
    }
    $req = [Sunet::Misc::Create_key_file[$keyfile]]
  } else {
    $req = []
  }

  ensure_resource('file', '/usr/local/sbin/cert-bundler', {
    ensure  => file,
    content => template('sunet/misc/cert-bundler.erb'),
    mode    => '0755'
  })

  $script_args = join($script, ' ')
  #notice("Creating ${outfile} with command /usr/local/sbin/cert-bundler --syslog $script_args")
  ensure_resource('exec', "create_${name}", {
    command => "/usr/local/sbin/cert-bundler --syslog $script_args",
    unless  => "/usr/local/sbin/cert-bundler --unless $script_args",
    require => $req,
    returns => [0, 1],
  })
}
