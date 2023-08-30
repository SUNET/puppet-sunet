# keygen
define sunet::snippets::keygen($key_file=undef,$cert_file=undef,$size=4096,$days=3650) {
  exec { "${title}_key":
    command => "openssl genrsa -out ${key_file} ${size}",
    onlyif  => "test ! -f ${key_file}",
    creates => $key_file
  }
  -> exec { "${title}_cert":
    command => "openssl req -x509 -sha256 -new -days ${days} -subj \"/CN=${title}\" -key ${key_file} -out ${cert_file}",
    onlyif  => "test ! -f ${cert_file} -a -f ${key_file}",
    creates => $cert_file
  }
}
