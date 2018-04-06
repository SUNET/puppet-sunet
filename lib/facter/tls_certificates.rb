# Gather all TLS certificates that we find on this host
Facter.add('tls_certificates') do
  res = {}

  # Look for dehydrated certs, keys and bundles
  filenames = Dir.glob('/etc/dehydrated/certs/*.pem')
  filenames.each do | full_fn |
    hostpart = File.basename(full_fn, '.pem')
    res[hostpart] ||= {}
    res[hostpart]['dehydrated_bundle'] = full_fn
    ['cert', 'privkey', 'chain', 'fullchain'].each do | part |
      partname = '/etc/dehydrated/certs/' + hostpart + '/' + part + '.pem'
      if part == 'privkey'
        part = 'key'  # consistency with non-dehydrated certs
      end
      if File.exists? partname
        res[hostpart]['dehydrated_' + part] = partname
      else
        warn("Not found: #{partname}")
      end
    end
  end

  # Look in /etc/ssl and /etc/ssl/private for crt/pem files with at least one underscore in them.
  # Assume what is to the left of the first underscore is a hostname and store the filename under
  # res[hostname][rest_of_path]
  filenames = Dir.glob(['/etc/ssl/*_*.pem',
                        '/etc/ssl/*_*.crt',
                        '/etc/ssl/private/*_*.pem',
                        '/etc/ssl/private/*_*.crt',
                        '/etc/ssl/private/*_*.key'
                       ])
  replace_end = {'.pem' => '',
                 '.crt' => '',
                 '.key' => '_key'
                }
  filenames.each do | full_fn |
    #debug("TLS certificate candidate: #{this}")
    fn = File.basename(full_fn)
    parts = fn.split('_')
    hostpart = parts.slice!(0)
    rest = parts.join('_')
    # Remove extension, or in the case of .key replace it with _key
    replace_end.each do | ext, value |
      if rest.end_with? ext
        rest = rest.chomp(ext)
        rest = rest + value
      end
    end
    if parts.count == 1 and fn.end_with? '.pem'
      # turn 'infra' into 'infra_cert'
      rest = rest + '_cert'
    end
    res[hostpart] ||= {}
    res[hostpart][rest] = full_fn
  end

  # Look for snakeoil cert, key and bundle
  snakeoil = {'bundle' => '/etc/ssl/snakeoil_bundle.crt',
              'cert'   => '/etc/ssl/certs/ssl-cert-snakeoil.pem',
              'key'    => '/etc/ssl/private/ssl-cert-snakeoil.key'
             }
  snakeoil.each do | key, fn |
    if File.exist? fn
      res['snakeoil'] ||= {}
      res['snakeoil'][key] = fn
    end
  end

  res.sort.each do | key, values |
    warn("TLS certificate found: #{key} #{values}")
  end
  setcode do
    res
  end
end
