{
  virtualisation.interfaces.eth1 = {
    vlan = 1;
    assignIP = false;
  };

  networking.ifstate.settings = {
    interfaces.eth1 = {
      addresses = [ ];
      link = {
        state = "up";
        kind = "physical";
      };
    };
  };
}
