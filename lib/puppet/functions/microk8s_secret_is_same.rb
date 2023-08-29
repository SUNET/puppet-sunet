# frozen_string_literal: true

Puppet::Functions.create_function(:microk8s_secret_is_same) do |args|
  err('Invalid use of function microk8s_secret_is_same') if args.size != 4

  namespace = args[0]
  name = args[1]
  key = args[2]
  value = args[3]

  command = "microk8s kubectl get secret #{name} -o jsonpath='{.data}' " \
    "-n #{namespace} | jq -r .#{key} | base64 --decode"
  result = `#{command}`
  return result == value
end
