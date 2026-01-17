let
  name = "public";
in
{
  virtualisation.interfaces.eth2 = {
    vlan = 2;
    assignIP = false;
  };

  networking = {
    iproute2 = {
      rttablesExtraConfig = ''
        10 ${name}
      '';
    };
    ifstate.settings.interfaces = {
      "${name}" = {
        link = {
          state = "up";
          kind = "vrf";
          vrf_table = name;
        };
      };
      eth2 = {
        addresses = [
          "203.0.113.2/30"
          "3fff:ffff:1515:200::2/64"
        ];
        link = {
          state = "up";
          kind = "physical";
          master = name;
        };
      };
    };
  };

  services.frr.config = ''
    vrf ${name}
      ip route 192.0.2.0/24 Null0
      ipv6 route 2001:db8::/40 Null0
    exit-vrf

    ip prefix-list own seq 10 permit 192.0.2.0/24
    ipv6 prefix-list own-6 seq 10 permit 2001:db8::/40

    ! announce only own and downstream prefixes
    route-map export permit 10
      match ip address prefix-list own
    exit
    route-map export permit 20
      match ip address prefix-list downstream1
    exit

    route-map export-6 permit 10
      match ipv6 address prefix-list own-6
    exit
    route-map export-6 permit 20
      match ipv6 address prefix-list downstream1-6
    exit

    router bgp 65550 vrf ${name}
      no bgp ebgp-requires-policy
      no bgp default ipv4-unicast
      bgp router-id 192.0.2.1

      # upstream
      neighbor 203.0.113.1 remote-as 64497
      neighbor 3fff:ffff:1515:200::1 remote-as 64497

      address-family ipv4 unicast
        network 192.0.2.0/24

        neighbor 203.0.113.1 activate
        neighbor 203.0.113.1 soft-reconfiguration inbound
        neighbor 203.0.113.1 route-map export out

        rd vpn export 65550:10
        rt vpn export 65550:1010
        rt vpn import 65550:1010 65550:1020 65550:1030

        import vpn
        export vpn
      exit-address-family

      address-family ipv6 unicast
        network 2001:db8::/40

        neighbor 3fff:ffff:1515:200::1 activate
        neighbor 3fff:ffff:1515:200::1 soft-reconfiguration inbound
        neighbor 3fff:ffff:1515:200::1 route-map export-6 out

        rd vpn export 65550:10
        rt vpn export 65550:1010
        rt vpn import 65550:1010 65550:1020 65550:1030

        import vpn
        export vpn
      exit-address-family
    exit
  '';
}
