{ lib, pkgs, ... }:
{
  name = "dns-knot-xfr-dnssec";

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
          server.automatic-acl = "on";

          remote = [
            {
              id = "secondary";
              address = [
                "192.0.2.11"
              ];
            }
          ];

          policy = [
            {
              id = "custom";
              signing-threads = "4";
              algorithm = "ECDSAP256SHA256";
              zsk-lifetime = "60d";
            }
          ];

          zone = [
            {
              domain = "example.com";
              notify = "secondary";
              file = pkgs.writeText "example.com" ''
                example.com.      IN  SOA  a.example.com hostmaster.example.com. (2025031200 86400 600 864000 60)
                example.com.      IN  NS   a.example.com.
                example.com.      IN  NS   b.example.com.
                example.com.      IN  A    198.51.100.10
              '';
              dnssec-signing = "on";
              dnssec-policy = "custom";
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
          server.automatic-acl = "on";

          remote = [
            {
              id = "primary";
              address = [
                "192.0.2.10"
              ];
            }
          ];

          zone = [
            {
              domain = "example.com";
              master = "primary";
              dnssec-signing = "on";
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

    with subtest("ensure zone is signed on primary"):
      a.wait_until_succeeds("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com RRSIG | grep RRSIG")
      a.wait_until_succeeds("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com DNSKEY | grep DNSKEY")

    with subtest("ensure zone is signed on secondary"):
      b.wait_until_succeeds("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com RRSIG | grep RRSIG")
      b.wait_until_succeeds("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com DNSKEY | grep DNSKEY")
  '';
}
