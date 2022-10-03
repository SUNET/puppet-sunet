module Puppet::Parser::Functions
  newfunction(:set_microk8s_secret, :type => :rvalue) do |args|
    if args.size != 3
      err('Invalid use of function set_microk8s_secret')
    end

    namespace = args[0]
    name = args[1]
    secret = args[2]

    command  = "microk8s kubectl -n #{namespace} create secret generic #{name} "
    secret.each do |key, value|
      command += "--from-literal=\"#{key}\"=\"#{value}\" "
    end
    command += "--dry-run=client -o yaml " +
               '| microk8s kubectl apply -f -'
    result = %x[#{command}]
    return result
  end
end
