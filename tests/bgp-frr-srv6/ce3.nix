{
  virtualisation.interfaces.eth1 = {
    vlan = 20;
    assignIP = false;
  };
  networking = {
    interfaces = {
      lo = {
        ipv4.addresses = [
          {
            address = "10.20.1.100";
            prefixLength = 32;
          }
        ];
        ipv6.addresses = [
          {
            address = "3fff:bbbb:1::100";
            prefixLength = 128;
          }
        ];
      };
      eth1 = { }; # set interface up
    };
  };
  services.frr = {
    bgpd.enable = true;
    config = ''
      ip route 10.20.1.0/24 reject
      ipv6 route 3fff:bbbb:1::/48 reject

      router bgp 65003
        no bgp ebgp-requires-policy
        no bgp reject-as-sets
        no bgp default ipv4-unicast
        no bgp network import-check
        neighbor eth1 interface remote-as 65000
        no neighbor eth1 enforce-first-as
        no neighbor eth1 capability link-local

        address-family ipv4 unicast
          network 10.20.1.0/24
          neighbor eth1 activate
          neighbor eth1 soft-reconfiguration inbound
        exit-address-family

        address-family ipv6 unicast
          network 3fff:bbbb:1::/48
          neighbor eth1 activate
          neighbor eth1 soft-reconfiguration inbound
        exit-address-family
      exit
    '';
  };
}
