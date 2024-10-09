# pyffd
define sunet::pyffd(
  $version = 'latest',
  $image = 'docker.sunet.se/pyff',
  $dir = '/opt/metadata',
  $pyffd_args = '',
  $pyffd_loglevel = 'INFO',
  $pipeline = 'mdx.fd')
{
  $sanitised_title = regsubst($title, '[^0-9A-Za-z.\-]', '-', 'G')

  ensure_resource(sunet::misc::system_user, 'haproxy', {group => 'haproxy' })
  $infra_cert = $facts['tls_certificates'][$::fqdn]['infra_cert']
  $infra_key = $facts['tls_certificates'][$::fqdn]['infra_key']
  ensure_resource(sunet::misc::certbundle, "${facts['networking']['fqdn']}_haproxy", {
    group  => 'haproxy',
    bundle => ["cert=${infra_cert}",
                "key=${infra_key}",
                "out=private/${facts['networking']['fqdn']}_haproxy.crt"],
  })

  ensure_resource('file','/opt/haproxy', { ensure => directory } )
  ensure_resource('file','/opt/haproxy/compose', { ensure => directory } )
  ensure_resource('file',$dir, { ensure => directory } )


  file { '/opt/haproxy/haproxy.cfg':
      content => template('sunet/pyffd/haproxy.cfg.erb'),
      owner   => root,
      group   => 'haproxy',
      mode    => '0640'
  }

  sunet::docker_compose {'pyffd_compose':
      service_name => 'mdq',
      description  => 'a pyffd+haproxy ensemble',
      compose_dir  => '/opt/haproxy/compose',
      content      => template('sunet/pyffd/compose.yml.erb'),
  }

  file {'/usr/local/bin/mirror-mdq.sh':
      ensure  => file,
      mode    => '0755',
      content => template('sunet/pyff/mirror-mdq.sh')
  }
}
