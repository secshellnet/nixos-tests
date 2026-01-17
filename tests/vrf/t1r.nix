{
  virtualisation.interfaces.eth1 = {
    vlan = 3;
    assignIP = false;
  };
  virtualisation.interfaces.eth2 = {
    vlan = 5;
    assignIP = false;
  };

  systemd.network = {
    enable = true;
    networks = {
      "10-eth1" = {
        matchConfig.Name = "eth1";
        address = [
          "fe80::2/64"
        ];
      };
      "20-eth2" = {
        matchConfig.Name = "eth2";
        address = [
          "198.51.100.65/26"
          "2001:db8:beef:20::1/64"
          "fe80::1/64"
        ];
      };
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  services.bird = {
    enable = true;
    config = ''
      log syslog all;
      router id 203.0.113.0;

      protocol device {
        scan time 10;
      }

      protocol kernel kernel4 {
        ipv4 {
          import none;
          export all;
        };
      }

      protocol kernel kernel6 {
        ipv6 {
          import none;
          export all;
        };
      }

      protocol static static4 {
        ipv4;

        route 198.51.100.0/24 unreachable;
      }

      protocol static static6 {
        ipv6;

        route 2001:db8:beef::/48 unreachable;
      }

      protocol bgp therouter {
        local as 65536;
        neighbor fe80::1 as 65550;
        interface "eth1";

        ipv4 {
          extended next hop on;
          import all;
          export all;
        };

        ipv6 {
          import all;
          export all;
        };
      }
    '';
  };
}
