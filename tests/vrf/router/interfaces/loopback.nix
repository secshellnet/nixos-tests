{
  networking.ifstate.settings.interfaces.loopback = {
    addresses = [
      "192.0.2.1/32"
      "2001:db8::1/128"
    ];
    link = {
      state = "up";
      kind = "dummy";
    };
  };
}
