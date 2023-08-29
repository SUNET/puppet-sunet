# frozen_string_literal: true

require 'json'
Puppet::Functions.create_function(:set_microk8s_secret) do |args|
  err('Invalid use of function set_microk8s_secret') if args.size != 3

  namespace = args[0]
  name = args[1]
  secret = args[2]

  command  = "microk8s kubectl -n #{namespace} create secret generic #{name} "
  secret.each do |item|
    key = item['key']
    value = item['value']
    command += "--from-literal=#{key}='#{value}' "
  end
  command += '--dry-run=client -o yaml ' \
             '| microk8s kubectl apply -f -'
  result = `#{command}`
  return result
end
