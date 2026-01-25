{ pkgs, lib, ... }:
{
  name = "dhcpv6-pd";

  defaults = {
    networking = {
      firewall.enable = false;
      useDHCP = lib.mkDefault false;
    };
  };

  nodes = {
    server = {
      virtualisation.interfaces.eth1 = {
        vlan = 1;
        assignIP = false;
      };

      networking.interfaces.eth1.ipv6.addresses = [
        {
          address = "2001:db8::1";
          prefixLength = 64;
        }
      ];

      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

      services = {
        kea.dhcp6 = {
          enable = true;
          settings = {
            interfaces-config.interfaces = [ "eth1" ];
            subnet6 = [
              {
                id = 1;
                subnet = "2001:db8::/48";
                interface = "eth1";
                pools = [
                  {
                    pool = "2001:db8::100-2001:db8::1ff";
                  }
                ];
                pd-pools = [
                  {
                    prefix = "2001:db8:0:1000::";
                    prefix-len = 52;
                    delegated-len = 56;
                  }
                ];
              }
            ];

          };
        };
        radvd = {
          enable = true;
          config = ''
            interface eth1 {
              AdvSendAdvert on;

              # Tell clients to use DHCPv6
              AdvManagedFlag on;
              AdvOtherConfigFlag on;

              prefix 2001:db8::/64 {
                AdvOnLink on;

                # Disable SLAAC, force DHCPv6
                AdvAutonomous off;
              };
            };
          '';
        };
      };
    };
    router = {
      virtualisation.interfaces = {
        eth1 = {
          vlan = 1;
          assignIP = false;
        };
        eth2 = {
          vlan = 2;
          assignIP = false;
        };
      };

      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

      systemd.network = {
        enable = true;
        networks = {
          "10-eth1" = {
            matchConfig.Name = "eth1";
            networkConfig = {
              IPv6AcceptRA = true;
              DHCP = "ipv6";
            };
            dhcpV6Config.PrefixDelegationHint = 56;
          };
          "20-eth2" = {
            matchConfig.Name = "eth2";
            networkConfig = {
              IPv6SendRA = true;
              DHCPPrefixDelegation = true;
            };
            dhcpPrefixDelegationConfig.UplinkInterface = "eth1";
          };
        };
      };
    };
    client = {
      virtualisation.interfaces.eth1 = {
        vlan = 2;
        assignIP = false;
      };
      networking.interfaces.eth1.ipv6.addresses = [ ];
    };
  };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          tcpdump
        ];
      })
      [
        "server"
        "router"
        "client"
      ]
  );

  testScript = ''
    start_all()

    server.wait_for_unit("network.target")
    server.wait_for_unit("radvd.service")
    server.wait_for_unit("kea-dhcp6-server.service")

    # Wait for IPv6 Duplicate Address Detection (DAD) to complete.
    server.wait_until_succeeds("""
      ip -j -6 a sh eth1 | \
        ${lib.getExe pkgs.jq} -e -r '.[] | .addr_info | .[] | select((.family == "inet6") and .scope == "link") | has("tentative") == false'
    """)

    server.succeed("systemctl restart kea-dhcp6-server")

    router.wait_for_unit("systemd-networkd.service")

    router.wait_until_succeeds("ip -6 -br a | grep -E 'eth1.*2001:db8::1[0-9a-f]{2}'", timeout=30)
    router.succeed("ip -6 route show default dev eth1 | grep default")

    router.succeed("ip -6 -br a | grep -E 'eth2.*2001:db8:0:1000:'")

    client.succeed("ip -6 -br a | grep -E 'eth1.*2001:db8:0:1000:'")
    client.succeed("ip -6 route show default dev eth1 | grep default")
  '';
}
