# Gather all TLS certificates that we find on this host
Facter.add('tls_certificates') do
  res = {}

  filenames = Dir.glob('/etc/dehydrated/certs/*.pem')
  filenames.each do | this |
    fn = File.basename(this, '.pem')
    res[fn] = {'bundle' => this}
  end

  filenames = Dir.glob('/etc/ssl/*_haproxy.crt')
  filenames.each do | this |
    fn = File.basename(this, '_haproxy.crt')
    if res.key?(fn)
      res[fn]['haproxy'] => this
    else
      res[fn] = {'haproxy' => this}
    end
  end

  if File.exist? '/etc/ssl/snakeoil_bundle.crt'
    res['snakeoil'] = {'bundle' => '/etc/ssl/snakeoil_bundle.crt'}
  end

  setcode do
    res
  end
end
