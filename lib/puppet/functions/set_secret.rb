Puppet::Functions.create_function(:'sunet::microk8s::set_secret') do
  dispatch :set_secret do
    required_param 'String', :namespace
    required_param 'String', :name
    required_param 'String', :key
    required_param 'String', :value
    return_type 'String'
  end

  def set_secret(namespace, name, key, value)
    command  = "microk8s kubectl -n #{namespace} create secret generic #{name}" +
    "--from-literal=#{key}=#{value} --dry-run=client -o yaml " +
    '| microk8s kubectl apply -f -'
    result = %x[ #{command} ]
    return result
  end
end
