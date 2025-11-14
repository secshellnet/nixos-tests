{ lib, pkgs, ... }:
{
  name = "dns-knot";

  nodes = {
    machine = {
      networking.useDHCP = false;
      services.knot = {
        enable = true;
        settings = {
          server.listen = [ "127.0.0.1@53" ];
          zone = [
            {
              domain = "example.com";
              file = pkgs.writeText "example.com" ''
                example.com.      IN  SOA  a.example.com hostmaster.example.com. (2025031200 86400 600 864000 60)
                example.com.      IN  NS   a.example.com.
                example.com.      IN  A    198.51.100.10
              '';
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
  '';
}
