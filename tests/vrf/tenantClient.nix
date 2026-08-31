{
  vlan,
  ipv4,
  ipv4cidr ? 24,
  ipv4gw,
  ipv6,
  ipv6cidr ? 64,
  ipv6gw ? "fe80::1",
}:
{
  virtualisation.interfaces.eth1 = {
    inherit vlan;
    assignIP = false;
  };
  networking = {
    interfaces.eth1 = {
      ipv4.addresses = [
        {
          address = ipv4;
          prefixLength = ipv4cidr;
        }
      ];
      ipv6.addresses = [
        {
          address = ipv6;
          prefixLength = ipv6cidr;
        }
      ];
    };
    defaultGateway = ipv4gw;
    defaultGateway6 = {
      address = ipv6gw;
      interface = "eth1";
    };
  };
}
