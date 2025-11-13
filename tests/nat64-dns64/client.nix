{
  virtualisation.interfaces.eth1 = {
    vlan = 2;
    assignIP = false;
  };
  networking.interfaces.eth1 = {
    ipv6.addresses = [
      {
        address = "2001:db8::2";
        prefixLength = 64;
      }
    ];
    ipv6.routes = [
      {
        address = "::";
        prefixLength = 0;
        via = "2001:db8::1";
      }
    ];
  };
  networking.nameservers = [ "2001:db8::1" ];
}
