{ lib, pkgs, ... }:
{
  name = "dns-knot-dnssec";

  nodes = {
    machine = {
      networking.useDHCP = false;
      services.knot = {
        enable = true;
        settings = {
          server.listen = [ "127.0.0.1@53" ];
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
              file = pkgs.writeText "example.com" ''
                example.com.      IN  SOA  a.example.com hostmaster.example.com. (2025031200 86400 600 864000 60)
                example.com.      IN  NS   a.example.com.
                example.com.      IN  A    198.51.100.10
              '';
              dnssec-signing = "on";
              dnssec-policy = "custom";
            }
          ];
        };
      };
    };
  };

  testScript = ''
    start_all()

    machine.wait_for_unit("network.target")
    machine.wait_for_unit("knot.service")

    machine.succeed("${lib.getExe pkgs.dig} +short @127.0.0.1 A example.com | grep 198.51.100.10")

    machine.succeed("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com RRSIG | grep RRSIG")
    machine.succeed("${lib.getExe pkgs.dig} +dnssec @127.0.0.1 example.com DNSKEY | grep DNSKEY")
  '';
}
