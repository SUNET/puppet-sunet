Puppet::Functions.create_function(:dir_glob) do
  def dir_glob(*arguments)
    Dir.glob(arguments[0]);
  end
end
