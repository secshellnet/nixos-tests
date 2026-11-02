{ lib, pkgs, ... }:
{
  virtualisation = {
    interfaces = {
      eth1 = {
        vlan = 4;
        assignIP = false;
      };
      eth2 = {
        vlan = 11;
        assignIP = false;
      };
      eth3 = {
        vlan = 6;
        assignIP = false;
      };
    };
  };
  systemd.network = {
    enable = true;
    config = {
      addRouteTablesToIPRoute2 = true;
      routeTables = {
        A = 101;
      };
    };
    networks = {
      "10-A" = {
        matchConfig.Name = "A";
        linkConfig = {
          ActivationPolicy = "up";
          RequiredForOnline = "no";
        };
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
        };
        routingPolicyRules = [
          {
            Priority = 500;
            From = "2001:db8:2:ffff::1";
            To = "2001:db8:1::/48";
          }
          {
            Priority = 500;
            From = "2001:db8:2:ffff::1";
            To = "2001:db8:3::/48";
          }
          {
            Priority = 32765;
            Table = "local";
            Family = "ipv4";
          }
          {
            Priority = 32765;
            Table = "local";
            Family = "ipv6";
          }
        ];
      };
      "20-lo" = {
        matchConfig.Name = "lo";
        address = [
          "2001:db8:2:ffff::1/128"
        ];
      };
      "30-eth1".matchConfig.Name = "eth1";
      "40-eth2" = {
        matchConfig.Name = "eth2";
        address = [
          "192.0.2.134/30"
          "2001:db8:10:132::2/64"
        ];
        networkConfig.VRF = "A";
      };
      "50-eth3".matchConfig.Name = "eth3";
    };
    netdevs."A" = {
      enable = true;
      netdevConfig = {
        Kind = "vrf";
        Name = "A";
      };
      vrfConfig.Table = 101;
    };
  };
  networking.localCommands = ''
    ip -4 rule del pref 0
    ip -6 rule del pref 0
  '';
  boot.kernel.sysctl = {
    "net.ipv6.conf.eth1.seg6_enabled" = 1;
    "net.ipv6.conf.eth3.seg6_enabled" = 1;

    "net.vrf.strict_mode" = 1; # not working
  };
  systemd.services.frr.preStart = ''
    ${lib.getExe' pkgs.busybox "sysctl"} -w net.vrf.strict_mode=1
  '';
  services.frr = {
    bgpd.enable = true;
    isisd.enable = true;
    config = ''
      ipv6 route 2001:db8:2::/48 blackhole

      vrf A
      exit-vrf

      interface eth1
        ipv6 router isis provider
      exit

      interface eth3
        ipv6 router isis provider
      exit

      interface lo
        ipv6 router isis provider
      exit

      router bgp 65000
        bgp router-id 10.0.0.2
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor PE peer-group
        neighbor PE remote-as internal
        no neighbor PE enforce-first-as
        neighbor PE update-source lo
        neighbor PE capability extended-nexthop
        neighbor 2001:db8:1:ffff::1 peer-group PE
        neighbor 2001:db8:1:ffff::1 description PE1
        no neighbor 2001:db8:1:ffff::1 enforce-first-as
        neighbor 2001:db8:3:ffff::1 peer-group PE
        neighbor 2001:db8:3:ffff::1 description PE3
        no neighbor 2001:db8:3:ffff::1 enforce-first-as

        segment-routing srv6
          locator L3VPN
        exit

        address-family ipv4 vpn
          neighbor PE activate
          neighbor PE next-hop-self
        exit-address-family

        address-family ipv6 vpn
          neighbor PE activate
          neighbor PE next-hop-self
        exit-address-family
      exit

      router bgp 65000 vrf A
        bgp router-id 10.0.0.2
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor 192.0.2.133 remote-as 65002
        no neighbor 192.0.2.133 enforce-first-as
        neighbor 2001:db8:10:132::1 remote-as 65002
        no neighbor 2001:db8:10:132::1 enforce-first-as
        sid vpn per-vrf export 101

        address-family ipv4 unicast
          neighbor 192.0.2.133 activate
          neighbor 192.0.2.133 soft-reconfiguration inbound
          rd vpn export 10.0.0.2:101
          rt vpn both 65000:101
          export vpn
          import vpn
        exit-address-family

        address-family ipv6 unicast
          neighbor 2001:db8:10:132::1 activate
          neighbor 2001:db8:10:132::1 soft-reconfiguration inbound
          rd vpn export 10.0.0.2:101
          rt vpn both 65000:101
          export vpn
          import vpn
        exit-address-family
      exit

      router isis provider
        is-type level-2-only
        net 49.0000.1920.0000.2002.00
        redistribute ipv6 static level-2
      exit

      segment-routing
        srv6
          locators
            locator L3VPN
              prefix 2001:db8:2:aaa::/64
              behavior usid
            exit
          exit
        exit
      exit
    '';
  };
}
