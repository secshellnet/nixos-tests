{ ... }:
{
  name = "bgp-frr-vpn-route-leak";

  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
  };

  nodes = {
    router = {
      networking.localCommands = ''
        ip link add public type vrf table 100
        ip link add internal type vrf table 200
        ip link add management type vrf table 300

        ip link add dum0 type dummy
        ip link set dum0 master management
        ip address add 198.51.100.100/32 dev dum0
        ip address add 2001:db8:100::100/128 dev dum0
      '';
      services.frr = {
        bgpd.enable = true;
        config = ''
          ip prefix-list own seq 10 permit 198.51.100.0/24
          ipv6 prefix-list own-6 seq 10 permit 2001:db8:100::/48

          ip prefix-list customer seq 10 permit 203.0.113.0/24
          ipv6 prefix-list customer-6 seq 10 permit 2001:db8:113::/48

          ip prefix-list default-route seq 10 permit 0.0.0.0/0
          ipv6 prefix-list default-route-6 seq 10 permit ::/0

          ip prefix-list too-small seq 10 permit 0.0.0.0/0 ge 25
          ipv6 prefix-list too-small-6 seq 10 permit ::/0 ge 49

          ! ipv4 prefixes to import from vpn into vrf public
          route-map public-in deny 10
            match ip address prefix-list too-small
          exit
          route-map public-in permit 20
            match ip address prefix-list own
          exit
          route-map public-in permit 30
            match ip address prefix-list customer
          exit

          ! ipv6 prefixes to import from vpn into vrf public
          route-map public-in-6 deny 10
            match ipv6 address prefix-list too-small-6
          exit
          route-map public-in-6 permit 20
            match ipv6 address prefix-list own-6
          exit
          route-map public-in-6 permit 30
            match ipv6 address prefix-list customer-6
          exit

          ! ipv4 prefixes to export from vrf public into vpn
          route-map public-out permit 10
            match ip address prefix-list default-route
          exit

          ! ipv6 prefixes to export from vrf public into vpn
          route-map public-out-6 permit 10
            match ipv6 address prefix-list default-route-6
          exit

          router bgp 208733
            no bgp default ipv4-unicast
          exit

          vrf internal
            ! own resources
            ip route 198.51.100.0/24 reject
            ipv6 route 2001:db8:100::/48 reject
          end-vrf

          router bgp 64496 vrf internal
            bgp router-id 192.0.2.1

            address-family ipv4 unicast
              network 198.51.100.0/24

              rd vpn export 64496:10
              rt vpn export 64496:100
              rt vpn import 64496:200 64496:300

              export vpn
              import vpn
            exit-address-family

            address-family ipv6 unicast
              network 2001:db8:100::/48

              rd vpn export 64496:10
              rt vpn export 64496:100
              rt vpn import 64496:200 64496:300

              export vpn
              import vpn
            exit-address-family
          exit

          vrf public
            ! fake default routes to leak into vpn
            ip route 0.0.0.0/0 reject
            ipv6 route ::/0 reject
          end-vrf

          router bgp 64496 vrf public
            no bgp ebgp-requires-policy
            bgp router-id 192.0.2.1

            address-family ipv4 unicast
              network 0.0.0.0/0

              rd vpn export 64496:20
              rt vpn export 64496:200
              rt vpn import 64496:100

              route-map vpn export public-out
              route-map vpn import public-in

              export vpn
              import vpn
            exit-address-family

            address-family ipv6 unicast
              network ::/0

              rd vpn export 64496:20
              rt vpn export 64496:200
              rt vpn import 64496:100

              route-map vpn export public-out-6
              route-map vpn import public-in-6

              export vpn
              import vpn
            exit-address-family
          exit

          vrf management
          end-vrf

          router bgp 64496 vrf management
            bgp router-id 198.51.100.100

            address-family ipv4 unicast
              ! redistribute loopback address
              redistribute connected

              rd vpn export 64496:30
              rt vpn export 64496:300
              rt vpn import 64496:100

              export vpn
              import vpn
            exit-address-family

            address-family ipv6 unicast
              ! redistribute loopback address
              redistribute connected

              rd vpn export 64496:30
              rt vpn export 64496:300
              rt vpn import 64496:100

              export vpn
              import vpn
            exit-address-family
          exit
        '';
      };
    };
  };

  testScript = ''
    start_all()

    router.wait_for_unit("network.target")
    router.wait_for_unit("network-local-commands.service")
    router.wait_for_unit("frr.service")

    with subtest("Own networks have been leaked into vrf public"):
      assert "B>* 198.51.100.0/24 [20/0] is directly connected, internal (vrf internal)" in router.succeed("vtysh show -c 'show ip route vrf public'")
      assert "B>* 2001:db8:100::/48 [20/0] is directly connected, internal (vrf internal)" in router.succeed("vtysh show -c 'show ipv6 route vrf public'")

    with subtest("Default route has been leaked into vrf internal"):
      assert "B>* 0.0.0.0/0 [20/0] is directly connected, public (vrf public)" in router.succeed("vtysh show -c 'show ip route vrf internal'")
      assert "B>* ::/0 [20/0] is directly connected, public (vrf public)" in router.succeed("vtysh show -c 'show ipv6 route vrf internal'")

    with subtest("Management loopback address has been leaked into vrf internal"):
      assert "B>* 198.51.100.100/32 [20/0] is directly connected, management (vrf management)" in router.succeed("vtysh show -c 'show ip route vrf internal'")
      assert "B>* 2001:db8:100::100/128 [20/0] is directly connected, management (vrf management)" in router.succeed("vtysh show -c 'show ipv6 route vrf internal'")

    with subtest("Own networks have been leaked into vrf management"):
      assert "B>* 198.51.100.0/24 [20/0] is directly connected, internal (vrf internal)" in router.succeed("vtysh show -c 'show ip route vrf management'")
      assert "B>* 2001:db8:100::/48 [20/0] is directly connected, internal (vrf internal)" in router.succeed("vtysh show -c 'show ipv6 route vrf management'")

    with subtest("Management vrf has default route"):
      # rt 64496:200 which contains default route not leaked into management vrf
      router.fail("ip -4 route show vrf management | grep default")
      router.fail("ip -6 route show vrf management | grep default")
  '';
}
