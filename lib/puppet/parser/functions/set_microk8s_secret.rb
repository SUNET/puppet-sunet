
module Puppet::Parser::Functions
  newfunction(:set_microk8s_secret, :type => :rvalue) do |args|

    if args.size != 4
      err('Invalid use of function set_secret')
    end

    namespace = args[0]
    name = args[1]
    key = args[2]
    value = args[3]

    command  = "microk8s kubectl -n #{namespace} create secret generic #{name}" +
    "--from-literal=#{key}=#{value} --dry-run=client -o yaml " +
    '| microk8s kubectl apply -f -'
    result = %x[ #{command} ]
    return result
  end
end
