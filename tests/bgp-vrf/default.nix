{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  name = "bgp-vrf";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.allowedTCPPorts = [ 179 ];
    };
  };

  nodes = {
    a = {
      imports = [ "${inputs.ifstate}/module.nix" ];
      environment.systemPackages = [ inputs.ifstate.packages.${pkgs.system}.default ];
      networking = {
        iproute2 = {
          enable = true;
          rttablesExtraConfig = ''
            10 vrf0
          '';
        };
        ifstate = {
          enable = true;
          package = inputs.ifstate.packages.${pkgs.system}.default;
          settings = {
            parameters.ignore.ifname = [
              "eth0"
            ];
            interfaces = {
              vrf0 = {
                link = {
                  state = "up";
                  kind = "vrf";
                  vrf_table = 10;
                };
              };
              eth1 = {
                addresses = [
                  "192.0.2.1/30"
                  "2001:db8::1/64"
                ];
                link = {
                  state = "up";
                  kind = "physical";
                  master = "vrf0";
                };
              };
            };
            sysctl.all = {
              ipv4.forwarding = 1;
              ipv6.forwarding = 1;
            };
          };
        };
      };

      services.frr = {
        bgpd.enable = true;
        config = ''
          vrf vrf0
            ip route 198.51.100.0/24 unreachable
            ipv6 route 2001:db8:beef::/48 unreachable
          exit-vrf

          router bgp 65001 vrf vrf0
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            no bgp network import-check
            bgp router-id 192.0.2.1

            neighbor 192.0.2.2 remote-as 65002
            neighbor 2001:db8::2 remote-as 65002

            address-family ipv4 unicast
              network 198.51.100.0/24
              neighbor 192.0.2.2 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:beef::/48
              neighbor 2001:db8::2 activate
            exit-address-family
        '';
      };
    };
    b = {
      systemd.network = {
        enable = true;
        config = {
          addRouteTablesToIPRoute2 = true;
          routeTables = {
            example = 10;
          };
        };
        networks = {
          "10-eth1" = {
            matchConfig.Name = "eth1";
            address = [
              "192.0.2.2/30"
              "2001:db8::2/64"
            ];
            networkConfig.VRF = "vrf0";
          };
          "99-vrf0" = {
            matchConfig.Name = "vrf0";
            linkConfig = {
              ActivationPolicy = "up";
              RequiredForOnline = "no";
            };
            networkConfig = {
              IPv4Forwarding = true;
              IPv6Forwarding = true;
            };
          };
        };
        netdevs."vrf0" = {
          enable = true;
          netdevConfig = {
            Kind = "vrf";
            Name = "vrf0";
          };
          vrfConfig.Table = 10;
        };
      };
      services.bird = {
        enable = true;
        package = pkgs.bird2;
        config = ''
          log syslog all;
          router id 192.0.2.2;

          ipv4 table vrf0_v4;
          ipv6 table vrf0_v6;

          protocol device {
            scan time 10;
          }

          protocol kernel kernel4 {
            vrf "vrf0";
            kernel table 10;

            ipv4 {
              export all;
            };
          }

          protocol kernel kernel6 {
            vrf "vrf0";
            kernel table 10;

            ipv6 {
              export all;
            };
          }

          protocol static static4 {
            vrf "vrf0";
            ipv4;

            route 203.0.113.0/24 unreachable;
          }

          protocol static static6 {
            vrf "vrf0";
            ipv6;

            route 2001:db8:c0de::/48 unreachable;
          }

          protocol bgp a4 {
            local as 65002;
            neighbor 192.0.2.1 as 65001;

            vrf "vrf0";

            ipv4 {
              import all;
              export all;
            };
          }

          protocol bgp a6 {
            local as 65002;
            neighbor 2001:db8::1 as 65001;

            vrf "vrf0";

            ipv6 {
              import all;
              export all;
            };
          }
        '';
      };
    };
  };

  testScript = ''
    start_all()

    for m in [a, b]:
      m.wait_for_unit("network.target")

    a.wait_for_unit("frr.service")
    b.wait_for_unit("bird.service")

    with subtest("ensure vrfs have been created"):
      for m in [a, b]:
        m.succeed("ip -j vrf | ${lib.getExe pkgs.jq} -r '.[] | .name' | grep vrf0")
        m.succeed("ip -j vrf | ${lib.getExe pkgs.jq} -r '.[] | .table' | grep 10")

    with subtest("ensure vrf interfaces can reach each other"):
      a.succeed("ip vrf exec vrf0 ping -c 1 192.0.2.2")
      b.succeed("ip vrf exec vrf0 ping -c 1 192.0.2.1")

    with subtest("ensure bgp sessions are established"):
      a.wait_until_succeeds("vtysh -c 'show bgp vrf vrf0 ipv4 summary' | grep '192.0.2.2.*1\\s*2\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a4.*Established'")

      # IPv6 DAD might need some time to complete for the local link address, which is required by frr
      a.wait_until_succeeds("vtysh -c 'show bgp vrf vrf0 ipv6 summary' | grep '2001:db8::2.*1\\s*2\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a6.*Established'")

    with subtest("ensure routes have been installed in vrf"):
      a.succeed("ip route show vrf vrf0 | grep 203.0.113.0/24")
      b.succeed("ip route show vrf vrf0 | grep 198.51.100.0/24")
      a.succeed("ip -6 route show vrf vrf0 | grep 2001:db8:c0de::/48")
      b.succeed("ip -6 route show vrf vrf0 | grep 2001:db8:beef::/48")
  '';
}
