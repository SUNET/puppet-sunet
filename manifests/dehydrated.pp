# dehydrated
class sunet::dehydrated(
  Boolean $staging = false,
  Boolean $cron = true,
  Boolean $cleanup = true,
  String  $src_url = 'https://raw.githubusercontent.com/dehydrated-io/dehydrated/master/dehydrated',
  Array   $allow_clients = [],
  Integer $server_port = 80,
  Integer $ssh_port = 22,
  String $version, 
) {
  $conf = lookup('dehydrated', undef, undef, undef)
  if $conf !~ Hash {
    fail("Hiera key 'dehydrated' is not a hash")
  }
  if ! has_key($conf, 'domains') {
    fail("Hiera hash 'dehydrated' does not contain 'domains'")
    # Old default domains hash if none was set:
    # [{$::fqdn => {"names" => [$::fqdn]}}]
  }
  $thedomains = $conf['domains']
  if $thedomains !~ Array[Hash] {
    fail("Unknown format of 'domains' - bailing out (why it should be a list of hashes instead of just a hash I do not know)")
  }

  $ca = 'https://acme-v02.api.letsencrypt.org/directory'
  
  ensure_resource('package','openssl',{ensure=>'latest'})
  $src_url = "https://raw.githubusercontent.com/dehydrated-io/dehydrated/refs/tags/${version}/dehydrated"
  sunet::remote_file { '/usr/sbin/dehydrated':
    remote_location => $src_url,
    mode            => '0755'
  }

  file {
    '/usr/bin/le-ssl-compat.sh':
      ensure  => 'file',
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      content => template('sunet/dehydrated/le-ssl-compat.erb')
      ;
    '/etc/dehydrated':
      ensure => 'directory',
      mode   => '0600',
      ;
    '/etc/dehydrated/config':
      ensure  => 'file',
      content => template('sunet/dehydrated/config.erb')
      ;
    '/etc/dehydrated/domains.txt':
      ensure  => 'file',
      content => template('sunet/dehydrated/domains.erb'),
      notify  => Exec['dehydrated-runonce']
      ;
    '/etc/dehydrated/dehydrated_wrapper.sh':
      ensure  => 'file',
      content => template('sunet/dehydrated/dehydrated_wrapper.sh.erb')
      ;
    '/etc/dehydrated/hook.sh':
      ensure  => 'file',
      content => template('sunet/dehydrated/dehydrated/hook.sh')
      ;
  }
  exec { 'dehydrated-runonce':
    # Run dehydrated once every time domains.txt changes;
    # UPDATE 2018-02, since we're using the wrapper now Nagios stuff will break if we run the old command
    # command     => '/usr/local/bin/scriptherder --mode wrap --syslog --name dehydrated -- /usr/sbin/dehydrated -c
    # && /usr/bin/le-ssl-compat.sh',
    command     => '/usr/local/bin/scriptherder --mode wrap --syslog --name dehydrated_per_domain -- /etc/dehydrated/dehydrated_wrapper.sh',
    refreshonly => true
  }

  if ($cron) {
    if ($cleanup) {
      $cmd = 'bash -c \'/usr/sbin/dehydrated --keep-going --no-lock -c && /usr/sbin/dehydrated --cleanup && /usr/bin/le-ssl-compat.sh\''
    } else {
      $cmd = 'bash -c \'/usr/sbin/dehydrated --keep-going --no-lock -c && /usr/bin/le-ssl-compat.sh\''
    }
    sunet::scriptherder::cronjob { 'dehydrated':
      cmd           => $cmd,
      special       => 'daily',
      ok_criteria   => ['exit_status=0','max_age=4d'],
      warn_criteria => ['exit_status=1','max_age=8d'],
    }
  }

  sunet::dehydrated::lighttpd_server { 'dehydrated_lighttpd_server':
    allow_clients => $allow_clients,
    server_port   => $server_port,
  }

  if has_key($conf, 'clients') {
    $clients = $conf['clients']
  } else {
    $clients = false
  }

  # clients is supposed to be a hash
  # thedomains is supposed to be a list of hashes for some reason
  each($thedomains) |$domain_hash| {
    each($domain_hash) |$domain,$info| {
      # Example: $domain = 'foo.sunet.se',
      #          $info = {names => [foo.sunet.se],
      #                   clients => [frontend1.sunet.se, frontend2.sunet.se]
      #                  }
      if (has_key($info,'ssh_key_type') and has_key($info,'ssh_key')) {
        sunet::rrsync { "/etc/dehydrated/certs/${domain}":
          ssh_key_type       => $info['ssh_key_type'],
          ssh_key            => $info['ssh_key'],
          use_sunet_ssh_keys => true,
        }
      }
    }
  }

  if $clients =~ Hash[String, Hash] {
    each($clients) |$client,$client_info| {
      # Make a list of all the domains that list this client in their 'clients' list
      $domain_list1 = $thedomains.map |$domain_hash| {
        $domain_hash.map |$domain, $info| {
          if has_key($info, 'clients') {
            if ($client in $info['clients']) {
              $domain
            }
          }
        }
      }
      # Make a flat list without undef entrys
      $domain_list = flatten($domain_list1).filter |$this| { $this != undef }
      # Make a space separated string with all the domain names
      $dirs = join($domain_list, ' ')

      # anyone that ssh:s in with this ssh_key will get the certs authorized for this client packaged using tar
      sunet::snippets::ssh_command2 { "dehydrated_${client}" :
        command      => "/bin/tar cf - -C /etc/dehydrated/certs/ ${dirs}",
        ssh_key_type => $clients[$client]['ssh_key_type'],
        ssh_key      => $clients[$client]['ssh_key']
      }
    }
  } elsif $clients != undef {
    warning("Unknown format of 'clients' - ignoring")
  }

  sunet::nftables::allow { 'allow-dehydrated-ssh':
    from => $allow_clients,
    port => $ssh_port,
  }
}

