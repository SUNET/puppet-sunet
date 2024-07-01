# Lock all local users, unless the file /etc/multiverse/UNSAFE_allow_local_users is present.
# @param unless_file  The file that, if present, will prevent this class from running.
class sunet::security::disable_all_local_users (
  String $unless_file = '/etc/multiverse/UNSAFE_allow_local_users',
) {
  exec { 'disable_all_local_users_exec':
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin',],
    command => 'cat /etc/passwd | awk -F : \'{print $1}\' | xargs --no-run-if-empty --max-args=1 usermod --lock',
    onlyif  => 'cat /etc/shadow | awk -F : \'{print $2}\' | grep -v ^!',
    before  => Package['openssh-server'],
    unless  => "test -f ${unless_file}",
  }
}
