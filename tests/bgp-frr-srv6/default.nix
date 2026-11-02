{ lib, pkgs, ... }:
{
  name = "bgp-frr-srv6";

  defaults = {
    networking = {
      useDHCP = false;
      firewall = {
        allowedTCPPorts = [ 179 ];
        extraCommands = ''
          ip6tables -I INPUT -m pkttype --pkt-type unicast -j ACCEPT
          ip6tables -I INPUT -m pkttype --pkt-type multicast -j ACCEPT
        '';
      };
    };
  };

  nodes = {
    p1 = import ./p1.nix;
    pe1 = import ./pe1.nix;
    pe2 = import ./pe2.nix;
    pe3 = import ./pe3.nix;
    ce1 = import ./ce1.nix;
    ce2 = import ./ce2.nix;
    ce3 = import ./ce3.nix;
    ce4 = import ./ce4.nix;
  };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          tcpdump
          pwru
        ];
      })
      [
        "pe1"
        "pe2"
        "pe3"
      ]
  );

  testScript =
    let
      jq = lib.getExe pkgs.jq;
    in
    ''
      start_all()

      for m in [p1, pe1, pe2, pe3, ce1, ce2, ce3, ce4]:
        m.wait_for_unit("network.target")

      pe1.wait_for_unit("network-local-commands.service")

      for m in [p1, pe1, pe2, pe3, ce1, ce3, ce4]:
        m.wait_for_unit("frr.service")
      ce2.wait_for_unit("bird.service")


      with subtest("Ensure ip rule reconfiguration on PE worked"):
        for m in [pe1, pe2, pe3]:
          m.fail("ip -4 --json rule | ${jq} -e 'any(.[]; .priority == 0)'")
          m.fail("ip -6 --json rule | ${jq} -e 'any(.[]; .priority == 0)'")
          m.succeed("ip -6 --json rule | ${jq} -e 'map(select(.priority == 500)) | length == 2'")


      with subtest("Ensure IS-IS found neighbors"):
        for m, interface in [
          (p1, "eth1"), (pe1, "eth1"),
          (p1, "eth2"), (pe2, "eth1"),
          (p1, "eth3"), (pe3, "eth1"),
          (pe1, "eth4"), (pe2, "eth3"),
        ]:
          m.wait_until_succeeds(f"""
            vtysh -c 'show isis neighbor json' | ${jq} -e -r '.areas[].circuits[] | select(.interface == "{interface}") | .state == "Up"'
          """)


      with subtest("Ensure IS-IS has ipv6 route"):
        for route in [f"2001:db8:{i}::/48" for i in range(1, 4)]:
          p1.wait_until_succeeds(f"vtysh -c 'show ipv6 route isis' | grep 'I>\\* '{route}")

        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:2::/48'")
        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:3::/48'")

        pe2.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:1::/48'")
        pe2.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:3::/48'")

        pe3.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:1::/48'")
        pe3.wait_until_succeeds("vtysh -c 'show ipv6 route isis' | grep 'I>\\* 2001:db8:2::/48'")


      with subtest("Ensure PE can ping each other"):
        pe1.wait_until_succeeds("ping -c 1 2001:db8:2:ffff::1")
        pe1.wait_until_succeeds("ping -c 1 2001:db8:3:ffff::1")

        pe2.wait_until_succeeds("ping -c 1 2001:db8:1:ffff::1")
        pe2.wait_until_succeeds("ping -c 1 2001:db8:3:ffff::1")

        pe3.wait_until_succeeds("ping -c 1 2001:db8:1:ffff::1")
        pe3.wait_until_succeeds("ping -c 1 2001:db8:2:ffff::1")


      with subtest("Ensure seg6 is enabled on interfaces towards provider network"):
        assert "= 1" in pe1.succeed("sysctl net.ipv6.conf.eth1.seg6_enabled")
        assert "= 1" in pe1.succeed("sysctl net.ipv6.conf.eth4.seg6_enabled")

        assert "= 1" in pe2.succeed("sysctl net.ipv6.conf.eth1.seg6_enabled")
        assert "= 1" in pe2.succeed("sysctl net.ipv6.conf.eth3.seg6_enabled")

        assert "= 1" in pe3.succeed("sysctl net.ipv6.conf.eth1.seg6_enabled")


      with subtest("Validate SRv6 SID exist"):
        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route bgp' | grep 'B>\\* 2001:db8:1:aaa:65::/128.*seg6local uDT46 table 101'")
        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route bgp' | grep 'B>\\* 2001:db8:1:aaa:66::/128.*seg6local uDT46 table 102'")
        pe2.wait_until_succeeds("vtysh -c 'show ipv6 route bgp' | grep 'B>\\* 2001:db8:2:aaa:65::/128.*seg6local uDT46 table 101'")
        pe3.wait_until_succeeds("vtysh -c 'show ipv6 route bgp' | grep 'B>\\* 2001:db8:3:aaa:66::/128.*seg6local uDT46 table 102'")


      with subtest("Validate routes are in the global IPv4 VPN table"):
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv4 vpn' | grep '\\*>\\s*10.10.1.0/24\\s*192.0.2.129@7<'")
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv4 vpn' | grep '\\*>\\s*10.20.1.0/24\\s*fe80::5054:ff:fe12:1403@8<'")
        pe2.wait_until_succeeds("vtysh -c 'show bgp ipv4 vpn' | grep '\\*>\\s*10.10.2.0/24\\s*192.0.2.133@6<'")
        pe3.wait_until_succeeds("vtysh -c 'show bgp ipv4 vpn' | grep '\\*>\\s*10.20.2.0/24\\s*fe80::5054:ff:fe12:1504@5<'")


      with subtest("Validate routes are in the global IPv6 VPN table"):
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv6 vpn' | grep '\\*>\\s*3fff:aaaa:1::/48\\s*2001:db8:10:128::1@7<'")
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv6 vpn' | grep '\\*>\\s*3fff:bbbb:1::/48\\s*fe80::5054:ff:fe12:1403@8<'")
        pe2.wait_until_succeeds("vtysh -c 'show bgp ipv6 vpn' | grep '\\*>\\s*3fff:aaaa:2::/48\\s*2001:db8:10:132::1@6<'")
        pe3.wait_until_succeeds("vtysh -c 'show bgp ipv6 vpn' | grep '\\*>\\s*3fff:bbbb:2::/48\\s*fe80::5054:ff:fe12:1504@5<'")


      with subtest("Validate IPv4 routes are received from the CE and are imported into the VRF from other PEs"):
        pe1.wait_until_succeeds("vtysh -c 'show bgp vrf A ipv4' | grep '\\*>\\s*10.10.1.0/24\\s*192.0.2.129'")
        pe1.wait_until_succeeds("vtysh -c 'show bgp vrf B ipv4' | grep '\\*>\\s*10.20.1.0/24\\s*eth3'")
        pe2.wait_until_succeeds("vtysh -c 'show bgp vrf A ipv4' | grep '\\*>\\s*10.10.2.0/24\\s*192.0.2.133'")
        pe3.wait_until_succeeds("vtysh -c 'show bgp vrf B ipv4' | grep '\\*>\\s*10.20.2.0/24\\s*eth2'")


      with subtest("Validate IPv6 routes are received from the CE and are imported into the VRF from other PEs"):
        pe1.wait_until_succeeds("vtysh -c 'show bgp vrf A ipv6' | grep '\\*>\\s*3fff:aaaa:1::/48\\s*fe80::5054:ff:fe12:a01'")
        pe1.wait_until_succeeds("vtysh -c 'show bgp vrf B ipv6' | grep '\\*>\\s*3fff:bbbb:1::/48\\s*eth3'")
        pe2.wait_until_succeeds("vtysh -c 'show bgp vrf A ipv6' | grep '\\*>\\s*3fff:aaaa:2::/48\\s*fe80::5054:ff:fe12:b02'")
        pe3.wait_until_succeeds("vtysh -c 'show bgp vrf B ipv6' | grep '\\*>\\s*3fff:bbbb:2::/48\\s*eth2'")


      with subtest("Verify IPv4 routes are installed into the Linux kernel"):
        pe1.wait_until_succeeds("vtysh -c 'show ip route vrf A' | grep 'B>\\* 10.10.1.0/24.*via 192.0.2.129, eth2'")
        pe1.wait_until_succeeds("vtysh -c 'show ip route vrf B' | grep 'B>\\* 10.20.1.0/24.*via fe80::5054:ff:fe12:1403, eth3'")
        pe2.wait_until_succeeds("vtysh -c 'show ip route vrf A' | grep 'B>\\* 10.10.2.0/24.*via 192.0.2.133, eth2'")
        pe3.wait_until_succeeds("vtysh -c 'show ip route vrf B' | grep 'B>\\* 10.20.2.0/24.*via fe80::5054:ff:fe12:1504, eth2'")


      with subtest("Verify IPv6 routes are installed into the Linux kernel"):
        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route vrf A' | grep 'B>\\* 3fff:aaaa:1::/48.*via fe80::5054:ff:fe12:a01, eth2'")
        pe1.wait_until_succeeds("vtysh -c 'show ipv6 route vrf B' | grep 'B>\\* 3fff:bbbb:1::/48.*via fe80::5054:ff:fe12:1403, eth3'")
        pe2.wait_until_succeeds("vtysh -c 'show ipv6 route vrf A' | grep 'B>\\* 3fff:aaaa:2::/48.*via fe80::5054:ff:fe12:b02, eth2'")
        pe3.wait_until_succeeds("vtysh -c 'show ipv6 route vrf B' | grep 'B>\\* 3fff:bbbb:2::/48.*via fe80::5054:ff:fe12:1504, eth2'")


      with subtest("Verify iBGP sessions are established"):
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:2:ffff::1.*1\\s*2\\s*PE2'")
        pe1.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:3:ffff::1.*1\\s*2\\s*PE3'")

        pe2.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:1:ffff::1.*2\\s*1\\s*PE1'")
        pe2.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:3:ffff::1.*1\\s*1\\s*PE3'")

        pe3.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:1:ffff::1.*2\\s*1\\s*PE1'")
        pe3.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8:2:ffff::1.*1\\s*1\\s*PE2'")


      with subtest("Customer A"):
        # ce1.succeed("ping -c 1 10.10.2.100")
        # ce2.succeed("ping -c 1 10.10.1.100")
        ce1.succeed("ping -c 1 3fff:aaaa:2::100")
        ce2.succeed("ping -c 1 3fff:aaaa:1::100")


      with subtest("Customer B"):
        # ce3.succeed("ping -c 1 10.20.2.100")
        # ce4.succeed("ping -c 1 10.20.1.100")
        ce3.succeed("ping -c 1 3fff:bbbb:2::100")
        ce4.succeed("ping -c 1 3fff:bbbb:1::100")


      with subtest("Customers can not reach each other"):
        # ce3.fail("ping -c 1 10.10.1.100")
        ce3.fail("ping -c 1 3fff:aaaa:1::100")
        # ce1.fail("ping -c 1 10.20.1.100")
        ce1.fail("ping -c 1 3fff:bbbb:1::100")
    '';
}
