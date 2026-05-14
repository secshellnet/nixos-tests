{ pkgs, lib, ... }:
{
  name = "dhcpv6";

  defaults = {
    networking = {
      firewall.enable = false;
      useDHCP = lib.mkDefault false;
    };

    # remove all existing addresses
    virtualisation.interfaces.eth1 = {
      vlan = 1;
      assignIP = false;
    };
  };

  nodes = {
    server = {
      networking.interfaces.eth1 = {
        ipv6.addresses = [
          {
            address = "2001:db8::1";
            prefixLength = 64;
          }
        ];
      };

      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

      services = {
        kea.dhcp6 = {
          enable = true;
          settings = {
            interfaces-config.interfaces = [ "eth1" ];
            subnet6 = [
              {
                id = 1;
                subnet = "2001:db8::/64";
                interface = "eth1";
                pools = [
                  {
                    pool = "2001:db8::100-2001:db8::1ff";
                  }
                ];
                option-data = [
                  {
                    name = "dns-servers";
                    data = "2001:db8::1";
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
    dhcpcd = {
      networking = {
        interfaces.eth1.useDHCP = true;
        dhcpcd = {
          enable = true;
          extraConfig = ''
            interface eth1
              dhcp6
              ipv6only
          '';
        };
      };
    };
    networkd = {
      systemd.network = {
        enable = true;
        networks."10-eth1" = {
          matchConfig.Name = "eth1";
          networkConfig = {
            IPv6AcceptRA = true;
            DHCP = "ipv6";
          };
        };
      };
    };
    nm = {
      networking.networkmanager = {
        enable = true;
        # this is needed so NM doesn't generate 'Wired Connection' profiles and instead uses the default one
        settings.main.no-auto-default = "*";
        ensureProfiles.profiles.eth1 = {
          connection = {
            id = "eth1";
            type = "ethernet";
            interface-name = "eth1";
            autoconnect = true;
          };
          ipv6.method = "auto";
        };
      };
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
        "dhcpcd"
        "networkd"
        "nm"
        "server"
      ]
  );

  testScript = ''
    server.start()
    server.wait_for_unit("network.target")
    server.wait_for_unit("radvd.service")
    server.wait_for_unit("kea-dhcp6-server.service")

    # Wait for IPv6 Duplicate Address Detection (DAD) to complete.
    server.wait_until_succeeds("""
      ip -j -6 a sh eth1 | \
        ${lib.getExe pkgs.jq} -e -r '.[] | .addr_info | .[] | select((.family == "inet6") and .scope == "link") | has("tentative") == false'
    """)

    server.succeed("systemctl restart kea-dhcp6-server")

    start_all()

    with subtest("dhcpcd"):
      dhcpcd.wait_for_unit("dhcpcd.service")

      dhcpcd.wait_until_succeeds("ip -6 -br a | grep -E 'eth1.*2001:db8::1[0-9a-f]{2}'", timeout=30)
      dhcpcd.succeed("cat /etc/resolv.conf | grep 'nameserver 2001:db8::1'")
      dhcpcd.succeed("ip -6 route show default dev eth1 | grep default")

    with subtest("systemd-networkd"):
      networkd.wait_for_unit("systemd-networkd.service")

      networkd.wait_until_succeeds("ip -6 -br a | grep -E 'eth1.*2001:db8::1[0-9a-f]{2}'", timeout=30)
      networkd.succeed("resolvectl status eth1 | grep 'DNS Servers: 2001:db8::1'")
      networkd.succeed("ip -6 route show default dev eth1 | grep default")

    with subtest("network manager"):
      nm.wait_for_unit("NetworkManager.service")

      nm.wait_until_succeeds("ip -6 -br a | grep -E 'eth1.*2001:db8::1[0-9a-f]{2}'", timeout=30)
      nm.succeed("cat /etc/resolv.conf | grep 'nameserver 2001:db8::1'")
      nm.succeed("ip -6 route show default dev eth1 | grep default")
  '';
}
