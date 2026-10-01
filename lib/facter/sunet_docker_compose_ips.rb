# Discover IP addresses of running docker-compose managed containers.
#
# Returns a nested hash:
#   { "<project>" => { "<service>" => { "ipv4" => "...", "ipv6" => "...", "network" => "..." } } }
#
# Absent (nil) if docker isn't available, the lookups fail, or no compose
# containers are found - never an empty hash.
require 'json'

Facter.add('sunet_docker_compose_ips') do
  setcode do
    begin
      res = {}

      ids_out = Facter::Core::Execution.execute(
        "docker container ls --filter label=com.docker.compose.project --format '{{.ID}}'",
        timeout: 10,
        on_fail: nil
      )

      if ids_out.nil?
        warn('sunet_docker_compose_ips: docker container ls failed or timed out')
        ids = []
      else
        ids = ids_out.split("\n").map(&:strip).reject(&:empty?)
      end

      if ids.empty?
        nil
      else
        inspect_out = Facter::Core::Execution.execute(
          "docker container inspect #{ids.join(' ')}",
          timeout: 20,
          on_fail: nil
        )

        if inspect_out.nil?
          warn('sunet_docker_compose_ips: docker container inspect failed or timed out')
        else
          containers = JSON.parse(inspect_out)

          containers.each do | container |
            labels = container.dig('Config', 'Labels') || {}
            project = labels['com.docker.compose.project']
            service = labels['com.docker.compose.service']
            next if project.nil? || service.nil?

            networks = container.dig('NetworkSettings', 'Networks') || {}
            next if networks.empty?

            default_name = "#{project}_default"
            if networks.key?(default_name)
              network_name = default_name
            elsif networks.size == 1
              network_name = networks.keys.first
            else
              network_name = networks.keys.sort.first
            end

            network = networks[network_name] || {}
            ipv4 = network['IPAddress']
            ipv4 = nil if ipv4 == ''
            ipv6 = network['GlobalIPv6Address']
            ipv6 = nil if ipv6 == ''

            res[project] ||= {}
            res[project][service] = {
              'ipv4'    => ipv4,
              'ipv6'    => ipv6,
              'network' => network_name,
            }
          end
        end

        res.empty? ? nil : res
      end
    rescue StandardError => e
      warn("sunet_docker_compose_ips: failed to gather docker compose container IPs: #{e}")
      nil
    end
  end
end
