# Make sure we have SWAMIDs QA key
define sunet::metadata::trust::swamid_qa {
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
  ensure_resource('file','/opt/metadata/trust/swamid/swamid-qa.crt', {
      content  => file('sunet/swamid-qa.crt')
  })
}

