# Mitegate the CVEs
class sunet::security::cve_mitegator (
  Array $excluded_cves = [],
)
{
  $_excluded_cves = lookup('excluded_cves', Array, undef, $excluded_cves)

  # Copy Fail CVE-2026-31431
  if !('CVE-2026-31431' in $_excluded_cves) {
    file { '/etc/modprobe.d/CVE-2026-31431.conf':
      ensure  => present,
      content => @("EOF"),
			  install algif_aead /bin/false
        | EOF
    }
    exec { 'CVE-2026-31431-blocked-modules':
      command     => 'rmmod algif_aead 2>/dev/null; true',
      subscribe   => File['/etc/modprobe.d/CVE-2026-43500.conf'],
      refreshonly => true,
    }

  # Dirty Frag CVE-2026-43500
  if !('CVE-2026-43500' in $_excluded_cves) {
    file { '/etc/modprobe.d/CVE-2026-43500.conf':
      ensure  => present,
      content => @("EOF"),
       install esp4 /bin/false
       install esp6 /bin/false
       install rxrpc /bin/false
       | EOF
    }
    exec { 'CVE-2026-43500-blocked-modules':
      command     => 'rmmod esp4 esp6 rxrpc 2>/dev/null; echo 3 > /proc/sys/vm/drop_caches; true',
      subscribe   => File['/etc/modprobe.d/CVE-2026-43500.conf'],
      refreshonly => true,
    }
  }

  # Copy Fail 2
  # No CVE yet?
  if !('Copy_Fail_2' in $_excluded_cves) {
    file { '/etc/modprobe.d/copy_fail_2.conf':
      ensure  => present,
      content => @("EOF"),
       install ipcomp4 /bin/false
       install ipcomp6 /bin/false
       | EOF
    }
    exec { 'copy-fail-2-blocked-modules':
      command     => 'rmmod ipcomp4 ipcomp6 2>/dev/null; true',
      subscribe   => File['/etc/modprobe.d/copy-fail-2.conf'],
      refreshonly => true,
    }
  }
}
