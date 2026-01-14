{
  virtualisation.interfaces.eth1 = {
    vlan = 2;
    assignIP = false;
  };

  systemd.network = {
    enable = true;
    netdevs.loopback = {
      enable = true;
      netdevConfig = {
        Kind = "dummy";
        Name = "loopback";
      };
    };
    networks = {
      "00-loopback" = {
        matchConfig.Name = "loopback";
        address = [
          "203.0.113.100/24"
          "3fff:ffff::100/32"
        ];
      };
      "10-eth1" = {
        matchConfig.Name = "eth1";
        address = [
          "203.0.113.1/30"
          "3fff:ffff:1515:200::1/64"
        ];
      };
    };
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

        route 203.0.113.0/24 unreachable;
      }

      protocol static static6 {
        ipv6;

        route 3fff:ffff::/32 unreachable;
      }

      protocol bgp therouter4 {
        local as 64497;
        neighbor 203.0.113.2 as 65550;

        ipv4 {
          import all;
          export all;
        };
      }

      protocol bgp therouter6 {
        local as 64497;
        neighbor 3fff:ffff:1515:200::2 as 65550;

        ipv6 {
          import all;
          export all;
        };
      }
    '';
  };
}
