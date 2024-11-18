# kopia policy
define sunet::kopia::policy(
  String $repository_name,
  String $user_name,
  String $keep_latest = '30',
  String $keep_hourly = 'inherit',
  String $keep_daily = 'inherit',
  String $keep_weekly = 'inherit',
  String $keep_monthly = 'inherit',
  String $keep_annual = 'inherit',
  String $snapshot_interval = '1h',
  String $compression = 'zstd-fastest',
){
  include sunet::package::kopia
  $dir_for_policy = "/opt/kopia/repositories/${repository_name}/mnt"
  $policy_name = "${user_name}@${facts['networking']['fqdn']}:${dir_for_policy}"
  $command = "kopia policy set --compression ${compression} \
    --keep-latest ${keep_latest} --keep-hourly ${keep_hourly} --keep-daily ${keep_daily} \
    --keep-weekly ${keep_weekly} --keep-monthly ${keep_monthly} --keep-annual ${keep_annual} \
    --snapshot_interval ${snapshot_interval} \
    ${policy_name}"

  exec { "kopia_policy_create_${policy_name}":
    command => $command,
  }
}
