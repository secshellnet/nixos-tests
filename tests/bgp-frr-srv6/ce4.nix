{
  virtualisation.interfaces.eth1 = {
    vlan = 21;
    assignIP = false;
  };
  networking = {
    ifstate = {
      enable = true;
      settings = {
        parameters.ignore.ifname = [
          "eth0"
        ];
        interfaces = {
          eth1.link = {
            state = "up";
            kind = "physical";
          };
          loopback = {
            addresses = [
              "10.20.2.100/32"
              "3fff:bbbb:2::100/128"
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
      };
    };
  };
  services.frr = {
    bgpd.enable = true;
    config = ''
      ip route 10.20.2.0/24 reject
      ipv6 route 3fff:bbbb:2::/48 reject

      router bgp 65004
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor eth1 interface remote-as 65000
        no neighbor eth1 enforce-first-as
        no neighbor eth1 capability link-local

        address-family ipv4 unicast
          network 10.20.2.0/24
          neighbor eth1 activate
          neighbor eth1 soft-reconfiguration inbound
        exit-address-family

        address-family ipv6 unicast
          network 3fff:bbbb:2::/48
          neighbor eth1 activate
          neighbor eth1 soft-reconfiguration inbound
        exit-address-family
      exit
    '';
  };
}
