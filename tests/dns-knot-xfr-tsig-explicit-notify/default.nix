{ lib, pkgs, ... }:
{
  name = "dns-knot-xfr-tsig-explicit-notify";

  defaults = {
    services.knot = {
      enable = true;
      settings.server.listen = [ "0.0.0.0@53" ];
    };
    networking = {
      useDHCP = false;
      firewall = {
        allowedUDPPorts = [ 53 ];
        allowedTCPPorts = [ 53 ];
      };
    };
  };

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.10";
            prefixLength = 31;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::";
            prefixLength = 64;
          }
        ];
      };
      services.knot = {
        settings = {
          key = [
            {
              id = "notify_key";
              algorithm = "hmac-sha256";
              secret = "bm90aWZ5LWludmFsaWQK";
            }
            {
              id = "xfr_key";
              algorithm = "hmac-sha256";
              secret = "eGZyLWludmFsaWQK";
            }
          ];

          remote = [
            {
              id = "secondary";
              address = [
                "192.0.2.11"
              ];
              key = "xfr_key";
            }
          ];

          acl = [
            {
              id = "xfr_to_secondary";
              key = "xfr_key";
              action = "transfer";
            }
            {
              id = "notify_to_secondary";
              key = "notify_key";
              action = "notify";
            }
          ];

          zone = [
            {
              domain = "example.com";
              notify = "secondary";
              acl = [
                "xfr_to_secondary"
                "notify_to_secondary"
              ];
              file = pkgs.writeText "example.com" ''
                example.com.      IN  SOA  a.example.com hostmaster.example.com. (2025031200 86400 600 864000 60)
                example.com.      IN  NS   a.example.com.
                example.com.      IN  NS   b.example.com.
                example.com.      IN  A    198.51.100.10
              '';
            }
          ];
        };
      };
    };
    b = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.11";
            prefixLength = 31;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::1";
            prefixLength = 64;
          }
        ];
      };
      services.knot = {
        settings = {
          key = [
            {
              id = "notify_key";
              algorithm = "hmac-sha256";
              secret = "bm90aWZ5LWludmFsaWQK";
            }
            {
              id = "xfr_key";
              algorithm = "hmac-sha256";
              secret = "eGZyLWludmFsaWQK";
            }
          ];

          remote = [
            {
              id = "primary";
              address = [
                "192.0.2.10"
              ];
              key = "xfr_key";
            }
          ];

          acl = [
            {
              id = "notify_from_primary";
              key = "notify_key";
              action = "notify";
            }
          ];

          zone = [
            {
              domain = "example.com";
              master = "primary";
              acl = "notify_from_primary";
            }
          ];
        };
      };
    };
  };

  testScript = ''
    start_all()

    for m in [a, b]:
      m.wait_for_unit("network.target")
      m.wait_for_unit("knot.service")

    for m in [a, b]:
      m.wait_until_succeeds("${lib.getExe pkgs.dig} +short @127.0.0.1 A example.com | grep 198.51.100.10")
  '';
}
