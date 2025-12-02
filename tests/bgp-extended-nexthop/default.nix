{ ... }:
{
  name = "bgp-extended-nexthop";

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

            address-family ipv4 unicast
              network 198.51.100.0/25
              neighbor fe80::2 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:beef::/48
              neighbor fe80::2 activate
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
            vrf "vrf0";
            ipv4;

            route 198.51.100.128/25 unreachable;
          }

          protocol static static6 {
            vrf "vrf0";
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
        '';
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
      a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'fe80::2.*1\\s*2\\s*N/A'")
      a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'fe80::2.*1\\s*2\\s*N/A'")
      b.wait_until_succeeds("birdc show protocols | grep 'a.*Established'")

    with subtest("ensure routes have been installed"):
      a.succeed("ip route show | grep 198.51.100.128/25")
      b.succeed("ip route show | grep 198.51.100.0/25")
      a.succeed("ip -6 route show | grep 2001:db8:c0de::/48")
      b.succeed("ip -6 route show | grep 2001:db8:beef::/48")
  '';
}
