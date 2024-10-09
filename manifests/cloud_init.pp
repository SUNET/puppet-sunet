# Reconfigure cloud init
class sunet::cloud_init {
  exec { 'update-cloud-init':
      command     => 'dpkg-reconfigure -f noninteractive cloud-init',
      refreshonly => true
  }
}

# Define a cloud-init config file
define sunet::cloud_init::config ($prio = '99', $config = {}) {
  ensure_resource ('class','sunet::cloud_init', { })
  file { "/etc/cloud/cloud.cfg.d/${prio}_${title}.cfg":
      owner   => root,
      group   => root,
      content => inline_template("<%= @config.to_yaml %>\n"),
      notify  => Exec['update-cloud-init']
  }
}

# Define a cloud-init config file for the IaaS
class sunet::cloud_init::iaas_defaults {
  sunet::cloud_init::config { 'disable_datasources':
      config => { datasource_list => [ 'None' ] }
  }
  sunet::cloud_init::config { 'keep_root_enabled':
      config => { disable_root => 'false' }
  }
}
