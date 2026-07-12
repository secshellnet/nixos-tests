{
  virtualisation.interfaces.eth1 = {
    vlan = 10;
    assignIP = false;
  };
  systemd.network = {
    enable = true;
    networks = {
      "10-lo" = {
        matchConfig.Name = "lo";
        address = [
          "10.10.1.100/32"
          "3fff:aaaa:1::100/128"
        ];
      };
      "20-eth1" = {
        matchConfig.Name = "eth1";
        address = [
          "192.0.2.129/30"
          "2001:db8:10:128::1/64"
        ];
      };
    };
  };
  services.frr = {
    bgpd.enable = true;
    config = ''
      route-map set-src permit 10
        set src 10.10.1.100
      exit

      route-map set-src-6 permit 10
        set src 3fff:aaaa:1::100
      exit

      ip protocol bgp route-map set-src
      ipv6 protocol bgp route-map set-src-6

      ip route 10.10.1.0/24 reject
      ipv6 route 3fff:aaaa:1::/48 reject

      router bgp 65001
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor 192.0.2.130 remote-as 65000
        no neighbor 192.0.2.130 enforce-first-as
        neighbor 2001:db8:10:128::2 remote-as 65000
        no neighbor 2001:db8:10:128::2 enforce-first-as

        address-family ipv4 unicast
          network 10.10.1.0/24
          neighbor 192.0.2.130 activate
          neighbor 192.0.2.130 soft-reconfiguration inbound
        exit-address-family

        address-family ipv6 unicast
          network 3fff:aaaa:1::/48
          neighbor 2001:db8:10:128::2 activate
          neighbor 2001:db8:10:128::2 soft-reconfiguration inbound
        exit-address-family
      exit
    '';
  };
}
