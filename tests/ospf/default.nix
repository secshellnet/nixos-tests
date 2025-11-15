{ lib, pkgs, ... }:
{
  name = "ospf";

  defaults = {
    networking.firewall.extraCommands = ''
      iptables -I INPUT -p 89 -j ACCEPT

      iptables -A INPUT -i eth1 -p igmp -j ACCEPT
      iptables -A INPUT -i eth1 -d 224.0.0.5 -j ACCEPT
      iptables -A INPUT -i eth1 -d 224.0.0.6 -j ACCEPT

      ip6tables -I INPUT -p 89 -j ACCEPT

      ip6tables -A INPUT -p icmpv6 --icmpv6-type 130 -j ACCEPT # MLD Query
      ip6tables -A INPUT -p icmpv6 --icmpv6-type 131 -j ACCEPT # MLD Report
      ip6tables -A INPUT -p icmpv6 --icmpv6-type 132 -j ACCEPT # MLD Done
      ip6tables -A INPUT -i eth1 -d ff02::5 -j ACCEPT
      ip6tables -A INPUT -i eth1 -d ff02::6 -j ACCEPT
    '';
  };

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.1";
            prefixLength = 30;
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
        ospfd.enable = true;
        ospf6d.enable = true;
        config = ''
          debug ospf event
          debug ospf6 event

          ip route 198.51.100.0/24 Null0
          ipv6 route 2001:db8:beef::/48 Null0

          interface eth1
            ip ospf area 0
            ipv6 ospf6 area 0
          exit

          router ospf
            ospf router-id 192.0.2.1
            redistribute static

          router ospf6
            ospf router-id 192.0.2.1
            redistribute static
        '';
      };
    };
    b = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.2";
            prefixLength = 30;
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
          router id 192.0.2.2;
          log syslog all;
          debug protocols all;

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
            route 203.0.113.0/24 blackhole;
          }
          protocol static static6 {
            ipv6;
            route 2001:db8:c0de::/48 blackhole;
          }

          protocol ospf v2 ospf4 {
            ipv4 {
              export all;
            };
            area 0 {
              interface "eth1" {
                wait 5;
              };
            };
          }
          protocol ospf v3 ospf6 {
            ipv6 {
              export all;
            };
            area 0 {
              interface "eth1" {
                wait 5;
              };
            };
          }
        '';
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
        "a"
        "b"
      ]
  );

  testScript =
    let
      jq = lib.getExe pkgs.jq;
    in
    ''
      start_all()

      for m in [a, b]:
        m.wait_for_unit("network.target")

      a.wait_for_unit("frr.service")
      b.wait_for_unit("bird.service")

      b.succeed("systemctl reload bird.service")

      with subtest("Ensure ospf is running"):
        a.wait_until_succeeds("vtysh -c 'show ip ospf neighbor' | grep Full/DR")
        a.wait_until_succeeds("vtysh -c 'show ipv6 ospf6 neighbor' | grep Full/DR")
        b.wait_until_succeeds("birdc show protocols ospf4 | grep Running")
        b.wait_until_succeeds("birdc show protocols ospf6 | grep Running")

      with subtest("Ensure routes are being advertised"):
        a.wait_until_succeeds("""
          ip --json r | ${jq} -e 'map(select(.dst == "203.0.113.0/24")) | any'
        """)
        b.wait_until_succeeds("""
          ip --json r | ${jq} -e 'map(select(.dst == "198.51.100.0/24")) | any'
        """)

        a.wait_until_succeeds("""
          ip --json -6 r | ${jq} -e 'map(select(.dst == "2001:db8:c0de::/48")) | any'
        """)
        b.wait_until_succeeds("""
          ip --json -6 r | ${jq} -e 'map(select(.dst == "2001:db8:beef::/48")) | any'
        """)
    '';
}
