{ lib, pkgs, ... }:
{
  virtualisation = {
    interfaces = {
      eth1 = {
        vlan = 5;
        assignIP = false;
      };
      eth2 = {
        vlan = 21;
        assignIP = false;
      };
    };
  };
  networking = {
    iproute2 = {
      enable = true;
      rttablesExtraConfig = ''
        102 B
      '';
    };
    localCommands = ''
      # https://github.com/FRRouting/frr/issues/15909
      ip -4 rule del pref 0
      ip -6 rule del pref 0
    '';
    ifstate = {
      enable = true;
      settings = {
        parameters.ignore.ifname = [
          "eth0"
        ];
        interfaces = {
          B.link = {
            state = "up";
            kind = "vrf";
            vrf_table = 102;
          };
          eth1 = {
            link = {
              state = "up";
              kind = "physical";
            };
            sysctl.ipv6.seg6_enabled = 1;
          };
          eth2.link = {
            state = "up";
            kind = "physical";
            master = "B";
          };
          loopback = {
            addresses = [
              "2001:db8:3:ffff::1/128"
            ];
            link = {
              state = "up";
              kind = "dummy";
            };
          };
        };
        sysctl.all = {
          ipv4.forwarding = 1;
          ipv6.forwarding = 1;
        };
        routing.rules = [
          {
            priority = 500;
            table = "main";
            from = "2001:db8:3:ffff::1";
            to = "2001:db8:1::/48";
          }
          {
            priority = 500;
            table = "main";
            from = "2001:db8:3:ffff::1";
            to = "2001:db8:2::/48";
          }
          {
            priority = 32765;
            table = "local";
          }
          {
            priority = 32765;
            table = "local";
            family = "inet6";
          }
        ];
      };
    };
  };
  boot.kernel.sysctl."net.vrf.strict_mode" = 1; # not working
  systemd.services.frr.preStart = ''
    ${lib.getExe' pkgs.busybox "sysctl"} -w net.vrf.strict_mode=1
  '';
  services.frr = {
    bgpd.enable = true;
    isisd.enable = true;
    config = ''
      ipv6 route 2001:db8:3::/48 blackhole

      vrf B
      exit-vrf

      interface eth1
        ipv6 router isis provider
      exit

      interface loopback
        ipv6 router isis provider
      exit

      router bgp 65000
        bgp router-id 10.0.0.3
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
        neighbor 2001:db8:2:ffff::1 peer-group PE
        neighbor 2001:db8:2:ffff::1 description PE2
        no neighbor 2001:db8:2:ffff::1 enforce-first-as

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

      router bgp 65000 vrf B
        bgp router-id 10.0.0.3
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor eth2 interface remote-as 65004
        no neighbor eth2 enforce-first-as
        no neighbor eth2 capability link-local
        sid vpn per-vrf export 102

        address-family ipv4 unicast
          neighbor eth2 activate
          neighbor eth2 soft-reconfiguration inbound
          rd vpn export 10.0.0.3:102
          rt vpn both 65000:102
          export vpn
          import vpn
        exit-address-family

        address-family ipv6 unicast
          neighbor eth2 activate
          neighbor eth2 soft-reconfiguration inbound
          rd vpn export 10.0.0.3:102
          rt vpn both 65000:102
          export vpn
          import vpn
        exit-address-family
      exit

      router isis provider
        is-type level-2-only
        net 49.0000.1920.0000.2003.00
        redistribute ipv6 static level-2
      exit

      segment-routing
        srv6
          locators
            locator L3VPN
              prefix 2001:db8:3:aaa::/64
              behavior usid
            exit
          exit
        exit
      exit
    '';
  };
}
