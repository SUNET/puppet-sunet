# Make sure we have SWAMIDs key
define sunet::metadata::trust::swamid {
  [
    '/opt/metadata',
    '/opt/metadata/trust',
    '/opt/metadata/trust/swamid'
    ].each |$dir| {
      ensure_resource('file', $dir, {
        ensure  => 'directory',
        mode    => '0700',
      })
    }
  ensure_resource('file','/opt/metadata/trust/swamid/md-signer2.crt', {
      content  => file('sunet/md-signer2.crt')
  })
}

