# frozen_string_literal: true

require 'json'
Puppet::Functions.create_function(:set_microk8s_secret) do
  def set_microk8s_secret(*arguments)
    err('Invalid use of function set_microk8s_secret') if arguments.size != 3
    namespace = arguments[0]
    name = arguments[1]
    secret = arguments[2]
    command  = "microk8s kubectl -n #{namespace} create secret generic #{name} "
    secret.each do |item|
      key = item['key']
      value = item['value']
      command += "--from-literal=#{key}='#{value}' "
    end
    command += '--dry-run=client -o yaml ' \
               '| microk8s kubectl apply -f -'
    `#{command}`
  end
end
