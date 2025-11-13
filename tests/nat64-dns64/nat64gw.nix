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
  boot.kernelModules = [ "jool" ]; # delays start by 90 seconds, due to startjob systemd-modules-load (not sure why)
  networking.jool = {
    enable = true;
    nat64.eth2.framework = "netfilter";
  };

  # dns64
  services.bind = {
    enable = true;
    listenOnIpv6 = [ "2001:db8::1" ];
    forwarders = [
      "192.0.2.2"
    ];
    cacheNetworks = [ "2001:db8::/64" ];
    # first line (comment) is to align config
    extraOptions = ''
      #
        dns64 64:ff9b::/96 {
          clients { any; };
          exclude { ::ffff:0:0/96; };
        };

        recursion yes;
        auth-nxdomain no;
        dnssec-validation no;
    '';
  };
}
