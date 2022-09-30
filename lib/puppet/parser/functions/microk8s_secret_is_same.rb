
module Puppet::Parser::Functions
  newfunction(:microk8s_secret_is_same, :type => :rvalue) do |args|

    if args.size != 4
      err('Invalid use of function microk8s_secret_is_same')
    end

    namespace = args[0]
    name = args[1]
    key = args[2]
    value = args[3]

    command  = "microk8s kubectl get secret #{name} -o jsonpath='{.data}' -n #{namespace} | jq -r .#{key} | base64 --decode"
    result = %x[ #{command} ]
    return result == value
  end
end
