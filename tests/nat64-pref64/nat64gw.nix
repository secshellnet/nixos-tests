{
  virtualisation.interfaces.eth1 = {
    vlan = 1;
    assignIP = false;
  };
  virtualisation.interfaces.eth2 = {
    vlan = 2;
    assignIP = false;
  };

  networking.interfaces.eth1 = {
    ipv4.addresses = [
      {
        address = "192.0.2.1";
        prefixLength = 24;
      }
    ];
  };

  networking.interfaces.eth2 = {
    ipv6.addresses = [
      {
        address = "2001:db8::1";
        prefixLength = 64;
      }
    ];
  };

  # nat64
  boot.kernelModules = [ "jool" ];
  networking.jool = {
    enable = true;
    nat64.eth2.framework = "netfilter";
  };

  services.dnsmasq = {
    enable = true;
    alwaysKeepRunning = true;
    settings = {
      listen-address = "2001:db8::1";
      no-hosts = true;
      no-resolv = true;
      server = [
        "192.0.2.2"
      ];
    };
  };

  services.radvd = {
    enable = true;
    config = ''
      interface eth2 {
        AdvSendAdvert on;
        prefix 2001:db8::/64 { };
        nat64prefix 64:ff9b::/96 { };
      };
    '';
  };
}
