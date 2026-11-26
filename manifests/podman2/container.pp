# A trusted module supplies the unit fragment and versioned image policy.
define sunet::podman2::container (
  Pattern[/\A[a-z][a-z0-9_]*\/[a-z][a-z0-9_]*\/[a-z0-9_-]+\z/] $profile,
  String[1] $quadlet,
  Pattern[/\As0:c\d+,c\d+\z/] $level,
  Hash $bindings,
  Array[Pattern[/\A[a-z][a-z0-9-]*\z/]] $after_units = [],
) {
  include sunet::podman2
  if !$sunet::podman2::lockdown or $title !~ /\A[a-z][a-z0-9-]*\z/ {
    fail("Invalid lockdown container declaration: ${title}")
  }
  [$namespace, $image, $revision] = split($profile, '/')
  $base = "${namespace}/podman2/images/${image}/${revision}"
  $spec = parseyaml(file("${base}/profile.yaml"))
  $module = $spec['module']
  if $module !~ /\A[a-z][a-z0-9_]*\z/ or $spec['revision'] != $revision {
    fail("Invalid module name or revision in ${profile}")
  }
  $record = {
    'name' => $title, 'profile' => $spec, 'source' => $profile,
    'cil' => file("${base}/${module}.cil"), 'quadlet' => $quadlet,
    'level' => $level, 'bindings' => $bindings, 'after' => $after_units,
  }
  concat::fragment { "podman2 container ${title}":
    target  => '/etc/sunet-podman2/catalog',
    content => inline_template('<%= @record.to_json %><%= "\n" %>'),
  }
}
