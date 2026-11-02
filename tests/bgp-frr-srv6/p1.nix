{
  virtualisation.interfaces = {
    eth1 = {
      vlan = 3;
      assignIP = false;
    };
    eth2 = {
      vlan = 4;
      assignIP = false;
    };
    eth3 = {
      vlan = 5;
      assignIP = false;
    };
  };
  # set interfaces up
  networking.interfaces = {
    eth1 = { };
    eth2 = { };
    eth3 = { };
  };
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  services.frr = {
    isisd.enable = true;
    config = ''
      interface eth1
        ipv6 router isis provider
      exit

      interface eth2
        ipv6 router isis provider
      exit

      interface eth3
        ipv6 router isis provider
      exit

      router isis provider
        is-type level-2-only
        net 49.0000.1920.0000.2000.00
      exit
    '';
  };
}
