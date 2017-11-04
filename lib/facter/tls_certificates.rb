# Gather all TLS certificates that we find on this host
Facter.add('tls_certificates') do
  res = {}

  filenames = Dir.glob('/etc/dehydrated/certs/*.pem')
  filenames.each do | this |
    fn = File.basename(this, '.pem')
    res[fn] = {'bundle' => this}
  end

  # Look in /etc/ssl and /etc/ssl/private for pem files with at least one underscore in them.
  # Assume what is left of the first underscore is a hostname and store the filename under
  # res[hostname][rest_of_path]
  filenames = Dir.glob(['/etc/ssl/private/*_*.pem', '/etc/ssl/private/*_*.pem'])
  filenames.each do | this |
    fn = File.basename(this, '.pem')
    hostpart, rest = fn.split('_')
    if ! res[hostpart]
      res[hostpart] = {}
    end
    res[hostpart][rest] = this
  end

  if File.exist? '/etc/ssl/snakeoil_bundle.crt'
    res['snakeoil'] = {'bundle' => '/etc/ssl/snakeoil_bundle.crt'}
  end

  setcode do
    res
  end
end
