# octorpki
class sunet::octorpki($version='1.3.0') {
      exec {'Add package':
      command => "https://github.com/cloudflare/cfrpki/releases/download/v${version}/octorpki_${version}_amd64.deb -O /root/octorpki_${version}_amd64.deb; dpkg -i /root/octorpki_${version}_amd64.deb",
      unless  => "test -f /root/octorpki_${version}_amd64.deb"
      }

      package { 'octorpki': ensure => installed }
      service { 'octorpki': ensure => 'running', enable => true, }
}
