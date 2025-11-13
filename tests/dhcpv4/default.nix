{ lib, ... }:
{
  name = "dhcpv4";

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = lib.mkForce [
          {
            address = "192.0.2.1";
            prefixLength = 24;
          }
        ];
        ipv6.addresses = lib.mkForce [ ];
      };
      services.kea.dhcp4 = {
        enable = true;
        settings = {
          interfaces-config.interfaces = [ "eth1" ];
          subnet4 = [
            {
              id = 1;
              subnet = "192.0.2.0/24";
              pools = [
                {
                  pool = "192.0.2.100-192.0.2.199";
                }
              ];
              option-data = [
                {
                  name = "domain-name-servers";
                  data = "192.0.2.1";
                }
                {
                  name = "routers";
                  data = "192.0.2.1";
                }
              ];
            }
          ];
        };
      };
    };
    b = {
      networking.interfaces = {
        # prevent creation of default route from management network
        eth0.useDHCP = false;
        eth1 = {
          ipv4.addresses = lib.mkForce [ ];
          ipv6.addresses = lib.mkForce [ ];
          useDHCP = true;
        };
      };
    };
  };

  testScript = ''
    a.start()
    a.wait_for_unit("network.target")
    a.wait_for_unit("kea-dhcp4-server.service")

    b.start()
    b.wait_for_unit("network.target")
    b.wait_for_unit("dhcpcd.service")

    b.succeed("ip -br a | grep -E 'eth1.*192.0.2.1[0-9]{2}'")
    b.succeed("cat /etc/resolv.conf | grep 'nameserver 192.0.2.1'")
    b.succeed("ip r | grep -E 'default.*192.0.2.1'")
  '';
}
