module Puppet::Parser::Functions
  newfunction(:dir_glob, :type => :rvalue) do |args|
    return Dir.glob(args[0]);
  end
end
