# Lock all local users
class sunet::security::disable_all_local_users () {
  exec { 'disable_all_local_users_exec':
    path    => ['/usr/sbin', '/usr/bin', '/sbin', '/bin',],
    command => 'cat /etc/passwd | awk -F : \'{print $1}\' | xargs --no-run-if-empty --max-args=1 usermod --lock',
    onlyif  => 'cat /etc/shadow | awk -F : \'{print $2}\' | grep -v ^!',
    before  => Package['openssh-server'],
  }
}
