{ pkgs, ... }:
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
          router bgp 65001
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor fe80::2 remote-as 65002
            neighbor fe80::2 capability extended-nexthop
            neighbor fe80::2 interface eth1

            address-family ipv4 unicast
              neighbor fe80::2 activate
            exit-address-family

            address-family ipv6 unicast
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
        package = pkgs.bird2;
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
          }

          protocol static static6 {
            ipv6;
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

    a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep 'fe80::2.*0\\s*0\\s*N/A'")
    a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep 'fe80::2.*0\\s*0\\s*N/A'")
    b.wait_until_succeeds("birdc show protocols | grep 'a.*Established'")
  '';
}
