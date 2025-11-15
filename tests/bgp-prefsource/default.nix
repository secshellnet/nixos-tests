{ ... }:
{
  name = "bgp-prefsource";

  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
  };

  nodes = {
    a = {
      networking.interfaces = {
        lo = {
          ipv4.addresses = [
            {
              address = "192.0.2.1";
              prefixLength = 32;
            }
          ];
          ipv6.addresses = [
            {
              address = "2001:db8::1";
              prefixLength = 128;
            }
          ];
        };
        eth1.ipv6.addresses = [
          {
            address = "fe80::1";
            prefixLength = 64;
          }
        ];
      };
      services.frr = {
        bgpd.enable = true;
        config = ''
          ip route 192.0.2.0/24 reject
          ipv6 route 2001:db8::/64 reject

          router bgp 65001
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor fe80::2 remote-as 65002
            neighbor fe80::2 capability extended-nexthop
            neighbor fe80::2 interface eth1

            address-family ipv4 unicast
              network 192.0.2.0/24
              neighbor fe80::2 activate
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8::/64
              neighbor fe80::2 activate
            exit-address-family

          route-map set-src permit 10
            set src 192.0.2.1
          exit

          route-map set-src-6 permit 10
            set src 2001:db8::1
          exit

          ip protocol bgp route-map set-src
          ipv6 protocol bgp route-map set-src-6
        '';
      };
    };
    b = {
      networking.interfaces = {
        lo = {
          ipv4.addresses = [
            {
              address = "198.51.100.1";
              prefixLength = 32;
            }
          ];
          ipv6.addresses = [
            {
              address = "3fff::1";
              prefixLength = 128;
            }
          ];
        };
        eth1.ipv6.addresses = [
          {
            address = "fe80::2";
            prefixLength = 64;
          }
        ];
      };
      services.bird = {
        enable = true;
        config = ''
          log syslog all;
          router id 198.51.100.1;

          protocol device {
            scan time 10;
          }

          protocol kernel kernel4 {
            ipv4 {
              import none;
              export filter {
                krt_prefsrc = 198.51.100.1;
                accept;
              };
            };
          }

          protocol kernel kernel6 {
            ipv6 {
              import none;
              export filter {
                krt_prefsrc = 3fff::1;
                accept;
              };
            };
          }

          protocol static static4 {
            ipv4;

            route 198.51.100.0/24 unreachable;
          }

          protocol static static6 {
            ipv6;

            route 3fff::/64 unreachable;
          }

          protocol bgp a {
            local as 65002;
            neighbor fe80::1 as 65001;
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

    a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'fe80::2.*1\\s*2\\s*N/A'")
    a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'fe80::2.*1\\s*2\\s*N/A'")
    b.wait_until_succeeds("birdc show protocols | grep 'a.*Established'")
  '';
}
