{ inputs, ... }:
{
  name = "bgp-simple";

  # required in node c - gobgp module
  node.pkgsReadOnly = false;

  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
  };

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.1";
            prefixLength = 29;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::1";
            prefixLength = 64;
          }
        ];
      };
      services.frr = {
        bgpd.enable = true;
        config = ''
          ip route 198.51.100.0/25 reject
          ipv6 route 2001:db8:beef::/48 reject
          router bgp 64496
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor 192.0.2.2 remote-as 64497
            neighbor 2001:db8::2 remote-as 64497

            neighbor 192.0.2.3 remote-as 64498
            neighbor 2001:db8::3 remote-as 64498

            address-family ipv4 unicast
              network 198.51.100.0/25
              neighbor 192.0.2.2 activate
              neighbor 192.0.2.3 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:beef::/48
              neighbor 2001:db8::2 activate
              neighbor 2001:db8::3 activate
            exit-address-family
        '';
      };
    };
    b = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.2";
            prefixLength = 29;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::2";
            prefixLength = 64;
          }
        ];
      };
      services.bird = {
        enable = true;
        config = ''
          log syslog all;
          router id 192.0.2.2;

          # The Device protocol is not a real routing protocol. It does not generate any
          # routes and it only serves as a module for getting information about network
          # interfaces from the kernel. It is necessary in almost any configuration.
          protocol device {
            scan time 10;
          }

          # The Kernel protocol is not a real routing protocol. Instead of communicating
          # with other routers in the network, it performs synchronization of BIRD
          # routing tables with the OS kernel. One instance per table.
          protocol kernel kernel4 {
            ipv4 {
              import none;
              export all;
            };
          }
          protocol kernel kernel6 {
            ipv6 {
              import none;
              export all;
            };
          }

          # Static routes (Again, there can be multiple instances, for different address
          # families and to disable/enable various groups of static routes on the fly).
          protocol static static4 {
            ipv4;

            route 198.51.100.128/25 unreachable;
          }
          protocol static static6 {
            ipv6;

            route 2001:db8:c0de::/48 unreachable;
          }

          protocol bgp a_v4 {
            local as 64497;
            neighbor 192.0.2.1 as 64496;

            ipv4 {
              import all;
              export all;
            };
          }

          protocol bgp c_v4 {
            local as 64497;
            neighbor 192.0.2.3 as 64498;

            ipv4 {
              import all;
              export all;
            };
          }

          protocol bgp a_v6 {
            local as 64497;
            neighbor 2001:db8::1 as 64496;

            ipv6 {
              import all;
              export all;
            };
          }

          protocol bgp c_v6 {
            local as 64497;
            neighbor 2001:db8::3 as 64498;

            ipv6 {
              import all;
              export all;
            };
          }
        '';
      };
    };
    c = {
      imports = [ inputs.gobgp.nixosModules.gobgp ];
      networking.interfaces = {
        eth1 = {
          ipv4.addresses = [
            {
              address = "192.0.2.3";
              prefixLength = 29;
            }
          ];
          ipv6.addresses = [
            {
              address = "2001:db8::3";
              prefixLength = 64;
            }
          ];
        };
        lo = {
          ipv4.routes = [
            {
              address = "203.0.113.0";
              prefixLength = 24;
            }
          ];
          ipv6.routes = [
            {
              address = "2001:db8:dead::";
              prefixLength = 48;
            }
          ];
        };
      };
      services.gobgpd = {
        enable = true;
        zebra = true;
        config = {
          global = {
            as = 64498;
            router-id = "192.0.2.3";
            apply-policy = {
              default-import-policy = "accept-route";
              export-policy-list = [ "c-out" ];
              default-export-policy = "reject-route";
            };
          };
          zebra = {
            enabled = true;
            redistribute-route-type-list = [
              "kernel"
              "directly-connected"
              "static"
            ];
          };
          neighbors = {
            "a-ipv4" = {
              neighbor-address = "192.0.2.1";
              peer-as = 64496;
              afi-safis."ipv4-unicast" = { };
            };
            "a-ipv6" = {
              neighbor-address = "2001:db8::1";
              peer-as = 64496;
              afi-safis."ipv6-unicast" = { };
            };
            "b-ipv4" = {
              neighbor-address = "192.0.2.2";
              peer-as = 64497;
              afi-safis."ipv4-unicast" = { };
            };
            "b-ipv6" = {
              neighbor-address = "2001:db8::2";
              peer-as = 64497;
              afi-safis."ipv6-unicast" = { };
            };
          };
          defined-sets.prefix-sets = {
            "c-out-ipv4".prefix-list = [
              {
                ip-prefix = "203.0.113.0/24";
                masklength-range = "24..32";
              }
            ];
            "c-out-ipv6".prefix-list = [
              {
                ip-prefix = "2001:db8:dead::/48";
                masklength-range = "48..128";
              }
            ];
          };
          policy-definitions."c-out" = {
            statements = {
              "c-out-ipv4" = {
                actions.route-disposition = "accept-route";
                conditions = {
                  match-prefix-set = {
                    prefix-set = "c-out-ipv4";
                    match-set-options = "any";
                  };
                };
              };
              "c-out-ipv6" = {
                actions.route-disposition = "accept-route";
                conditions = {
                  match-prefix-set = {
                    prefix-set = "c-out-ipv6";
                    match-set-options = "any";
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  testScript = ''
    start_all()

    a.wait_for_unit("network.target")
    b.wait_for_unit("network.target")
    c.wait_for_unit("network.target")

    a.wait_for_unit("frr.service")
    b.wait_for_unit("bird.service")
    c.wait_for_unit("gobgpd.service")

    with subtest("ensure bgp sessions are established"):
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep '192.0.2.2.*2\\s*3\\s*N/A'")
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep '192.0.2.3.*1\\s*3\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a_v4.*Established'")
      b.wait_until_succeeds("birdc show protocols | grep 'c_v4.*Established'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv4' | grep '192.0.2.1.*Establ.*|.*3.*2'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv4' | grep '192.0.2.2.*Establ.*|.*2.*2'")

      # IPv6 DAD might need some time to complete for the local link address, which is required by frr
      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8::2.*2\\s*3\\s*N/A'")
      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8::3.*1\\s*3\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a_v6.*Established'")
      b.wait_until_succeeds("birdc show protocols | grep 'c_v4.*Established'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv6' | grep '2001:db8::1.*Establ.*|.*3.*2'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv6' | grep '2001:db8::2.*Establ.*|.*2.*2'")

    with subtest("ensure routes have been installed in fib"):
      b.succeed("ip route show | grep 198.51.100.0/25")
      c.succeed("ip route show | grep 198.51.100.0/25")
      a.succeed("ip route show | grep 198.51.100.128/25")
      c.succeed("ip route show | grep 198.51.100.128/25")
      a.succeed("ip route show | grep 203.0.113.0/24")
      b.succeed("ip route show | grep 203.0.113.0/24")
      b.succeed("ip -6 route show | grep 2001:db8:beef::/48")
      c.succeed("ip -6 route show | grep 2001:db8:beef::/48")
      a.succeed("ip -6 route show | grep 2001:db8:c0de::/48")
      c.succeed("ip -6 route show | grep 2001:db8:c0de::/48")
      a.succeed("ip -6 route show | grep 2001:db8:dead::/48")
      b.succeed("ip -6 route show | grep 2001:db8:dead::/48")
  '';
}
