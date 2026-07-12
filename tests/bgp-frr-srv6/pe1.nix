{ lib, pkgs, ... }:
{
  virtualisation = {
    interfaces = {
      eth1 = {
        vlan = 3;
        assignIP = false;
      };
      eth2 = {
        vlan = 10;
        assignIP = false;
      };
      eth3 = {
        vlan = 20;
        assignIP = false;
      };
      eth4 = {
        vlan = 6;
        assignIP = false;
      };
    };
  };
  networking = {
    interfaces = {
      lo.ipv6.addresses = [
        {
          address = "2001:db8:1:ffff::1";
          prefixLength = 128;
        }
      ];
      eth1 = { }; # set interface up
      eth2 = {
        ipv4.addresses = [
          {
            address = "192.0.2.130";
            prefixLength = 30;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8:10:128::2"; # TODO not working
            prefixLength = 64;
          }
        ];
      };
      eth3 = { }; # set interface up
      eth4 = { }; # set interface up
    };
    localCommands = ''
      ip -4 rule del pref 0
      ip -4 rule add from all lookup local pref 32765

      ip -6 rule del pref 0
      ip -6 rule add from all lookup local pref 32765

      ip -6 rule add from 2001:db8:3:ffff::1 to 2001:db8:2::/48 lookup main pref 500
      ip -6 rule add from 2001:db8:3:ffff::1 to 2001:db8:3::/48 lookup main pref 500

      ip link add A type vrf table 101
      ip link add B type vrf table 102

      ip link set eth2 master A
      ip link set eth3 master B

      ip link set A up
      ip link set B up

      ip addr add 2001:db8:10:128::2/64 dev eth2
    '';
  };
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    "net.ipv6.conf.eth1.seg6_enabled" = 1;
    "net.ipv6.conf.eth4.seg6_enabled" = 1;

    "net.vrf.strict_mode" = 1; # not working
  };
  systemd.services.frr.preStart = ''
    ${lib.getExe' pkgs.busybox "sysctl"} -w net.vrf.strict_mode=1
  '';
  services.frr = {
    bgpd.enable = true;
    isisd.enable = true;
    config = ''
      ipv6 route 2001:db8:1::/48 blackhole

      vrf A
      exit-vrf

      vrf B
      exit-vrf

      interface eth1
        ipv6 router isis provider
      exit

      interface eth4
        ipv6 router isis provider
      exit

      interface lo
        ipv6 router isis provider
      exit

      router bgp 65000
        bgp router-id 10.0.0.1
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor PE peer-group
        neighbor PE remote-as internal
        no neighbor PE enforce-first-as
        neighbor PE update-source lo
        neighbor PE capability extended-nexthop
        neighbor 2001:db8:2:ffff::1 peer-group PE
        neighbor 2001:db8:2:ffff::1 description PE2
        no neighbor 2001:db8:2:ffff::1 enforce-first-as
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
        bgp router-id 10.0.0.1
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor 192.0.2.129 remote-as 65001
        no neighbor 192.0.2.129 enforce-first-as
        neighbor 2001:db8:10:128::1 remote-as 65001
        no neighbor 2001:db8:10:128::1 enforce-first-as
        sid vpn per-vrf export 101

        address-family ipv4 unicast
          neighbor 192.0.2.129 activate
          neighbor 192.0.2.129 soft-reconfiguration inbound
          rd vpn export 10.0.0.1:101
          rt vpn both 65000:101
          export vpn
          import vpn
        exit-address-family

        address-family ipv6 unicast
          neighbor 2001:db8:10:128::1 activate
          neighbor 2001:db8:10:128::1 soft-reconfiguration inbound
          rd vpn export 10.0.0.1:101
          rt vpn both 65000:101
          export vpn
          import vpn
        exit-address-family
      exit

      router bgp 65000 vrf B
        bgp router-id 10.0.0.1
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor eth3 interface remote-as 65003
        no neighbor eth3 enforce-first-as
        no neighbor eth3 capability link-local
        sid vpn per-vrf export 102

        address-family ipv4 unicast
          neighbor eth3 activate
          neighbor eth3 soft-reconfiguration inbound
          rd vpn export 10.0.0.1:102
          rt vpn both 65000:102
          export vpn
          import vpn
        exit-address-family

        address-family ipv6 unicast
          neighbor eth3 activate
          neighbor eth3 soft-reconfiguration inbound
          rd vpn export 10.0.0.1:102
          rt vpn both 65000:102
          export vpn
          import vpn
        exit-address-family
      exit

      router isis provider
        is-type level-2-only
        net 49.0000.1920.0000.2001.00
        redistribute ipv6 static level-2
      exit

      segment-routing
        srv6
          locators
            locator L3VPN
              prefix 2001:db8:1:aaa::/64
              behavior usid
            exit
          exit
        exit
      exit
    '';
  };
}
