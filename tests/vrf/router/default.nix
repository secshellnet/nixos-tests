{
  imports = [
    ./interfaces
    ./nat.nix
  ];

  services.frr = {
    bgpd.enable = true;
    # The default bgp instance MUST exist for vrf route leaks to work properly
    config = ''
      router bgp 65550
      exit
    '';
  };

  boot.kernel.sysctl = {
    # enable ip forwarding
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;

    # bind sockets to all vrf's
    "net.ipv4.tcp_l3mdev_accept" = 1;
    "net.ipv4.udp_l3mdev_accept" = 1;
  };
}
