
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
