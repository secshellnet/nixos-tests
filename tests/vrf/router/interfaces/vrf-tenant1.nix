let
  name = "tenant1";
in
{
  virtualisation.interfaces.eth4 = {
    vlan = 4;
    assignIP = false;
  };

  networking = {
    iproute2 = {
      rttablesExtraConfig = ''
        30 ${name}
      '';
    };
    ifstate.settings = {
      interfaces = {
        eth4 = {
          addresses = [
            "10.0.10.1/24"
            "2001:db8:10::1/64"
            "fe80::1/64"
          ];
          link = {
            state = "up";
            kind = "physical";
            master = name;
          };
        };
        "${name}" = {
          addresses = [
            "192.0.2.255/32"
          ];
          link = {
            state = "up";
            kind = "vrf";
            vrf_table = name;
          };
        };
      };
      routing.routes = [
        {
          to = "0.0.0.0/0";
          dev = "public";
        }
        {
          to = "::/0";
          dev = "public";
        }
      ];
    };

    nftables.tables.nat.content = ''
      chain postrouting {
        ip saddr 10.0.10.0/24 oifname eth2 snat to 192.0.2.255
      }
    '';
  };

  services.frr.config = ''
    vrf ${name}
    exit-vrf

    ip prefix-list tenant1nat seq 10 permit 192.0.2.255/32
    route-map tenant1-to-public permit 10
      match ip address prefix-list tenant1nat
    exit

    ipv6 prefix-list tenant1nat-6 seq 10 permit 2001:db8:10::/64
    route-map tenant1-to-public-6 permit 10
      match ipv6 address prefix-list tenant1nat-6
    exit

    router bgp 65550 vrf ${name}
      no bgp ebgp-requires-policy
      no bgp default ipv4-unicast
      bgp router-id 192.0.2.1

      address-family ipv4 unicast
        redistribute connected route-map tenant1-to-public

        rd vpn export 65550:30
        rt vpn both 65550:1030

        import vpn
        export vpn
      exit-address-family

      address-family ipv6 unicast
        redistribute connected route-map tenant1-to-public-6

        rd vpn export 65550:30
        rt vpn both 65550:1030

        import vpn
        export vpn
      exit-address-family
    exit
  '';
}
