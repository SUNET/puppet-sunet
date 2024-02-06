# frozen_string_literal: true

Puppet::Functions.create_function(:microk8s_secret_is_same) do
  def microk8s_secret_is_same(*arguments)
    err('Invalid use of function microk8s_secret_is_same') if arguments.size != 4

    namespace = arguments[0]
    name = arguments[1]
    key = arguments[2]
    value = arguments[3]

    command = "microk8s kubectl get secret #{name} -o jsonpath='{.data}' " \
      "-n #{namespace} | jq -r .#{key} | base64 --decode"
    result = `#{command}`
    result == value
  end
end
