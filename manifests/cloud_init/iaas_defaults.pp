# Define a cloud-init config file for the IaaS
class sunet::cloud_init::iaas_defaults {
  sunet::cloud_init::config { 'disable_datasources':
      config => { datasource_list => [ 'None' ] }
  }
  sunet::cloud_init::config { 'keep_root_enabled':
      config => { disable_root => 'false' }
  }
}
