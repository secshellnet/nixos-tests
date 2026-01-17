{
  vlan,
  ipv4,
  ipv4cidr ? 24,
  ipv4gw,
}:
{
  virtualisation.interfaces.eth1 = {
    inherit vlan;
    assignIP = false;
  };
  networking = {
    interfaces.eth1.ipv4.addresses = [
      {
        address = ipv4;
        prefixLength = ipv4cidr;
      }
    ];
    defaultGateway = ipv4gw;
  };
}
