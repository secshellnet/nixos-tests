{
  virtualisation.interfaces.eth1 = {
    vlan = 11;
    assignIP = false;
  };
  networking.interfaces = {
    lo = {
      ipv4.addresses = [
        {
          address = "10.10.2.100";
          prefixLength = 32;
        }
      ];
      ipv6.addresses = [
        {
          address = "3fff:aaaa:2::100";
          prefixLength = 128;
        }
      ];
    };
    eth1 = {
      ipv4.addresses = [
        {
          address = "192.0.2.133";
          prefixLength = 30;
        }
      ];
      ipv6.addresses = [
        {
          address = "2001:db8:10:132::1";
          prefixLength = 64;
        }
      ];
    };
  };
  services.bird = {
    enable = true;
    config = ''
      log syslog all;
      router id 10.10.2.100;

      protocol device {
        scan time 10;
      }

      protocol kernel kernel4 {
        ipv4 {
          import none;
          export filter {
            krt_prefsrc = 10.10.2.100;
            accept;
          };
        };
      }
      protocol kernel kernel6 {
        ipv6 {
          import none;
          export filter {
            krt_prefsrc = 3fff:aaaa:2::100;
            accept;
          };
        };
      }

      protocol static static4 {
        ipv4;

        route 10.10.2.0/24 unreachable;
      }
      protocol static static6 {
        ipv6;

        route 3fff:aaaa:2::/48 unreachable;
      }

      protocol bgp pe2_v4 {
        local as 65002;
        neighbor 192.0.2.134 as 65000;

        ipv4 {
          import all;
          export all;
        };
      }

      protocol bgp pe2_v6 {
        local as 65002;
        neighbor 2001:db8:10:132::2 as 65000;

        ipv6 {
          import all;
          export all;
        };
      }
    '';
  };
}
