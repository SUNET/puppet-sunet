Puppet::Functions.create_function('sunet::microk8s::set_secret') do
  dispatch :set_secret do
    param 'String', :namespace
    param 'String', :name
    param 'String', :key
    param 'String', :value
  end

  def set_secret(namespace, name, key, value)
    command  = "microk8s kubectl -n #{namespace} create secret generic #{name}" +
    "--from-literal=#{key}=#{value} --dry-run=client -o yaml " +
    '| microk8s kubectl apply -f -'
    result = %x[ #{command} ]
  end
end
