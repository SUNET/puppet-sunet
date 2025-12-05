# frozen_string_literal: true

Puppet::Functions.create_function(:sunet_servers) do
  dispatch :sunet_servers do
    optional_param 'Struct[{
      Optional[tags] => Array[Enum["knubbis","infraca"]],
      Optional[family] => Enum["ip", "ip6", "inet"],

    }]', :options
  end

  def sunet_servers(options = {})
    requested_tags = options['tags'] || ["all"]
    requested_family = options['family'] || "inet"

    return_value = []
    data = _data_source()

    data.each do | entry |
      tags=entry[:tags].append("all")
      family=entry[:family]
      if (requested_tags & tags).empty?
          next
      end

      if (requested_family != "inet")
        if (requested_family != family)
            next
        end
      end

      return_value.append(entry[:net])
    end

    return return_value
  end

  def _data_source
  [
      { "net": "2001:6b0:1e:2::22d/128","family": "ip6", "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "130.242.3.49/32",       "family": "ip",  "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "2001:6b0:1e:2::231/128","family": "ip6", "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "130.242.3.241/32",      "family": "ip",  "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "2001:6b0:1e:2::22f/128","family": "ip6", "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "130.242.3.125/32",      "family": "ip",  "comment": "", "resource_type": "SUNIC", "tags": [
        "knubbis",
      ]},
      { "net": "130.242.121.23/32",     "family": "ip",  "comment": "", "resource_type": "VPN",   "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "192.36.171.192/26",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:40::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "94.176.224.0/24",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "89.47.190.0/23",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:8::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "192.36.171.64/26",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "192.36.171.128/26",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "130.242.132.0/24",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "130.242.131.0/24",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "89.45.236.0/22",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "89.47.184.0/23",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "89.46.20.0/22",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "130.242.130.0/24",     "family": "ip",  "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:64::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:63::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:7d:40::/64",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:1e::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:6b0:6e::/48",      "family": "ip6", "comment": "", "resource_type": "SUNET", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "3.123.104.206/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "184.72.45.62/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "18.156.124.185/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "18.195.9.86/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "54.177.34.135/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "13.56.217.109/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "18.158.14.16/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "54.219.108.181/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "3.101.5.178/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "3.101.5.178/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "54.193.162.123/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "18.157.244.215/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "3.71.178.160/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "184.169.227.115/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "18.158.37.246/32",     "family": "ip",  "comment": "", "resource_type": "seamlessaccess", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "130.242.126.192/28",     "family": "ip",  "comment": "", "resource_type": "sunetfrontend", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "2001:948:4:6::111/128",     "family": "ip6",  "comment": "", "resource_type": "nagiosxi", "tags": [
        "knubbis",
        "infraca",
      ]},
      { "net": "109.105.111.111",     "family": "ip",  "comment": "", "resource_type": "nagiosxi", "tags": [
        "knubbis",
        "infraca",
      ]},
    ]
  end
end
