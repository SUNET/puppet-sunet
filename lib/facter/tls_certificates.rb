# Gather all TLS certificates that we find on this host
Facter.add('tls_certificates') do
  filenames = Dir.glob('/etc/dehydrated/certs/*.pem')
  res = {}

  filenames.each do | this |
    fn = File.basename(this, '.pem')
    res[fn] = {'bundle' => this}
  end

  if File.exist? '/etc/ssl/snakeoil_bundle.crt'
    res['snakeoil'] = {'bundle' => '/etc/ssl/snakeoil_bundle.crt'}
  end

  setcode do
    res
  end
end
