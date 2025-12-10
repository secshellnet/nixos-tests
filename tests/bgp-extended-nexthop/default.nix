{ inputs, ... }:
{
  name = "bgp-extended-nexthop";

  # required in node c - gobgp module
  node.pkgsReadOnly = false;

  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
  };

  nodes = {
    a = {
      networking.interfaces.eth1.ipv6.addresses = [
        {
          address = "fe80::1";
          prefixLength = 64;
        }
      ];
      services.frr = {
        bgpd.enable = true;
        config = ''
          ip route 198.51.100.0/25 reject
          ipv6 route 2001:db8:beef::/48 reject

          router bgp 64496
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor fe80::2 remote-as 64497
            neighbor fe80::2 capability extended-nexthop
            neighbor fe80::2 interface eth1

            neighbor fe80::3 remote-as 64498
            neighbor fe80::3 capability extended-nexthop
            neighbor fe80::3 interface eth1

            address-family ipv4 unicast
              network 198.51.100.0/25
              neighbor fe80::2 activate
              neighbor fe80::3 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:beef::/48
              neighbor fe80::2 activate
              neighbor fe80::3 activate
            exit-address-family
        '';
      };
    };
    b = {
      networking.interfaces.eth1.ipv6.addresses = [
        {
          address = "fe80::2";
          prefixLength = 64;
        }
      ];
      services.bird = {
        enable = true;
        config = ''
          log syslog all;
          router id 192.0.2.2;

          protocol device {
            scan time 10;
          }

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

          protocol static static4 {
            ipv4;

            route 198.51.100.128/25 unreachable;
          }

          protocol static static6 {
            ipv6;

            route 2001:db8:c0de::/48 unreachable;
          }

          protocol bgp a {
            local as 64497;
            neighbor fe80::1 as 64496;
            interface "eth1";

            ipv4 {
              extended next hop on;
              import all;
              export all;
            };

            ipv6 {
              import all;
              export all;
            };
          }

          protocol bgp c {
            local as 64497;
            neighbor fe80::3 as 64498;
            interface "eth1";

            ipv4 {
              extended next hop on;
              import all;
              export all;
            };

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
      networking.interfaces.eth1.ipv6.addresses = [
        {
          address = "fe80::3";
          prefixLength = 64;
        }
      ];
      services.gobgpd = {
        enable = true;
        zebra = true;
        validateConfig = false;
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
          static-paths = {
            "unreachable-ipv4".prefix = "203.0.113.0/24";
            "unreachable-ipv6".prefix = "2001:db8:dead::/48";
          };
          neighbors = {
            "a" = {
              neighbor-address = "fe80::1%eth1";
              peer-as = 64496;
              afi-safis = {
                "ipv4-unicast" = { };
                "ipv6-unicast" = { };
              };
            };
            "b" = {
              neighbor-address = "fe80::2%eth1";
              peer-as = 64497;
              afi-safis = {
                "ipv4-unicast" = { };
                "ipv6-unicast" = { };
              };
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

    a.wait_for_unit("frr.service")
    b.wait_for_unit("bird.service")

    with subtest("ensure bgp sessions are established"):
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'fe80::2.*2\\s*3\\s*N/A'")
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'fe80::3.*1\\s*3\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a.*Established'")
      b.wait_until_succeeds("birdc show protocols | grep 'c.*Established'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv4' | grep 'fe80::1%eth1.*Establ.*|.*3.*2'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv4' | grep 'fe80::2%eth1.*Establ.*|.*2.*2'")

      # IPv6 DAD might need some time to complete for the local link address, which is required by frr
      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'fe80::2.*2\\s*3\\s*N/A'")
      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'fe80::3.*1\\s*3\\s*N/A'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv6' | grep 'fe80::1%eth1.*Establ.*|.*3.*2'")
      c.wait_until_succeeds("gobgp neighbor -a 'ipv6' | grep 'fe80::2%eth1.*Establ.*|.*2.*2'")

    with subtest("ensure routes have been installed"):
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
