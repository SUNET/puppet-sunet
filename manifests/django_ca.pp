# This puppet manifest is used to configure the sunet implementation of django-ca

# @param environment                        The environment, test, prod ... (used for nft fw opening)
# @param django_ca_servicename              The service name (fqdn) of the django-ca instance
# @param hsm_partition                      The name of the HSM partition where the django-ca root keys reside
# @param hsm_servers                        List of HSM servers used by the CA
# @param django_ca_db_servicename           The service name (fqdn) of the database used by django-ca
# @param django_ca_admin_gui                Enable or disable the django-ca admin web-gui
# @param django_ca_bg_task_runner           If running multiple app servers, only one should run background tasks
# @param django_ca_cmc                      Enable the CMS feature
# @param config_dir                         The local directory on the server where all config is stored
# @param django_ca_tag                      The version of djanog-ca to run
# @param nginx_tag                          The version of nginx to run
# @param server_fqdn                        The fqdn of the server, used in nginx.conf
class sunet::django_ca (
  Enum['test', 'prod']      $environment,
  String                    $django_ca_servicename,
  String                    $hsm_partition,
  Array                     $hsm_servers,
  String                    $django_ca_db_servicename,
  Boolean                   $django_ca_admin_gui = false,
  Boolean                   $django_ca_bg_task_runner = false,
  Boolean                   $django_ca_cmc = false,
  String                    $config_dir = '/opt/django-ca',
  String                    $django_ca_tag = 'latest',
  String                    $nginx_tag = '1.29-bookworm',
  String                    $server_fqdn = $facts['networking']['fqdn'],
) {

  # Allow HTTPS from load balancer servers
  $lb_ips = hiera_array("lb_${environment}_servers",[])
  sunet::nftables::allow { 'allow-https-from-lbs':
    from => $lb_ips,
    port => 443,
  }

  # Get the HSM pin from hiera
  $pkcs11_pin = safe_hiera('pkcs11_pin')
  # Get the django-ca database password
  $djangoca_db_password = safe_hiera('djangoca_db_password')
  # Get the django-ca secret key
  $django_ca_secret_key = safe_hiera('django_ca_secret_key')

  # Create django-ca config file
  file { "${config_dir}/django-ca.yaml":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sunet/django-ca/django-ca.yaml.erb'),
  }

  # Create nginx config file
  file { "${config_dir}/nginx.conf":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('sunet/django-ca/nginx.conf.erb'),
  }

  sunet::hsm::client_trust { 'hsms':
      hsm_servers => $hsm_servers,
      mode        => '0755',
  }
  sunet::hsm::client_auth {'client_cert':
      mode => '0755',
  }

  sunet::hsm::client_chrystoki {'/etc/Chrystoki.conf':
      hsm_servers => $hsm_servers,
  }

  file { "/usr/safenet/lunaclient/cert/client/${server_fqdn}.pem":
    ensure => file,
    mode   => '0755',
  }

  file { "/usr/safenet/lunaclient/cert/client/${server_fqdn}Key.pem":
    ensure => file,
    mode   => '0755',
  }

  # Wrapper to easier access django-ca
  file { '/usr/local/bin/django-ca':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => file('sunet/django-ca/django-ca'),
  }

  # Run django-ca
  sunet::docker_compose { 'django-ca':
    content          => template('sunet/django-ca/docker-compose.yml.erb'),
    service_name     => 'django-ca',
    compose_dir      => '/opt/',
    compose_filename => 'docker-compose.yml',
    description      => 'django-ca',
    mode             => '0755'
  }

  # Run django-ca background tasks (since we do not use celery beat:
  # https://django-ca.readthedocs.io/en/latest/quickstart/as_app.html#setup-regular-tasks)
  if $django_ca_bg_task_runner {
    sunet::scriptherder::cronjob { 'django-ca-regenerate_ocsp_keys':
      cmd         => '/usr/local/bin/django-ca regenerate_ocsp_keys',
      minute      => '20',
      ok_criteria => ['exit_status=0', 'max_age=3h'],
    }
    sunet::scriptherder::cronjob { 'django-ca-cache_crls':
      cmd         => '/usr/local/bin/django-ca cache_crls',
      minute      => '25',
      ok_criteria => ['exit_status=0', 'max_age=3h'],
    }
    sunet::scriptherder::cronjob { 'django-ca-acme_cleanup':
      # XXX future version of django-ca will probably contain preconfigured argument which can replace this shell execution
      cmd         => '/usr/local/bin/django-ca shell -c "import django_ca.tasks; django_ca.tasks.acme_cleanup"',
      minute      => '*/5',
      ok_criteria => ['exit_status=0', 'max_age=3h'],
    }
  }

  ## Monitoring
  # nrpe commands file
  file { '/etc/nagios/nrpe.d/nrpe-djangoca.cfg':
    ensure  => 'file',
    mode    => '0644',
    owner   => 'root',
    content => file('eid/connector/nrpe-djangoca.cfg')
  }
  # Custom monitoring scripts
  file { '/usr/local/sbin/check-djangoca-status.sh':
    ensure  => 'file',
    mode    => '0755',
    owner   => 'root',
    content => file('eid/connector/check-djangoca-status.sh')
  }

}
