# frozen_string_literal: true

# Inspect the final catalog, including declarations evaluated after the host class.
Puppet::Functions.create_function(:'sunet::enforce_podman2_catalog', Puppet::Functions::InternalFunction) do
  dispatch :register_check do
    scope_param
  end

  def register_check(scope)
    validator = Class.new(Puppet::Parser::Compiler::CatalogValidator) do
      def validate
        catalog.resources.each do |resource|
          next unless resource.type.to_s.downcase == 'file'
          next if resource[:ensure].to_s == 'absent'

          path = (resource[:path] || resource.title).to_s
          rootless = path.match?(%r{/(?:\.config/containers/systemd|containers/systemd/users|containers/systemd/users\.d)/})
          direct_unit = rootless && (path.match?(/\.(?:container|kube|pod)(?:$|\.d\/)/) || resource[:recurse])
          user_service = path.match?(%r{/(?:\.config/systemd/user|systemd/user)/[^/]+\.service$})
          manual = user_service && resource[:content].to_s.match?(/\bpodman(?:-compose)?\b/)
          if direct_unit || manual
            raise Puppet::Parser::Compiler::CatalogValidationError,
                  "Use sunet::podman2::container with an image profile for #{path} on this enrolled host"
          end
        end
      end
    end
    scope.compiler.add_catalog_validator(validator)
    nil
  end
end
