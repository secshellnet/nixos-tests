{ lib, pkgs, ... }:
{
  name = "nat64-dns64";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.enable = false;
    };
  };

  nodes = {
    server = import ./server.nix { inherit pkgs; };
    nat64gw = import ./nat64gw.nix;
    client = import ./client.nix;
  };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          curl
          dig
        ];
      })
      [
        "server"
        "client"
        "nat64gw"
      ]
  );

  testScript =
    let
      curl = lib.getExe pkgs.curl;
      dig = lib.getExe pkgs.dig;
    in
    ''
      start_all()

      for m in [server, nat64gw, client]:
        m.wait_for_unit("network.target")

      server.wait_for_unit("nginx.service")
      server.wait_for_unit("bind.service")
      nat64gw.wait_for_unit("bind.service")
      nat64gw.wait_for_unit("jool-nat64-eth2.service")

      with subtest('ensure "public" dns server is working properly'):
        assert server.succeed("${dig} +short A example.com").strip() == "192.0.2.2"
        assert server.succeed("${dig} +short AAAA example.com").strip() == ""

      with subtest('ensure http server is online'):
        server.succeed("${curl} -sI http://example.com")

      with subtest('ensure ipv4 network between server and gateway is working'):
        server.succeed("ping -c 1 192.0.2.1")
        nat64gw.succeed("ping -c 1 192.0.2.2")

      # first dig fails for whatever reason
      nat64gw.succeed("${dig} A example.com @2001:db8::1")

      with subtest('ensure dns64 works as expected locally'):
        assert nat64gw.succeed("${dig} +short A example.com @2001:db8::1").strip() == "192.0.2.2"
        assert nat64gw.succeed("${dig} +short AAAA example.com @2001:db8::1").strip() == "64:ff9b::c000:202"

      with subtest('ensure ipv6 network between gateway and client is working'):
        nat64gw.succeed("ping -6 -c 1 2001:db8::2")
        client.succeed("ping -6 -c 1 2001:db8::1")

      with subtest('ensure dns64 works as expected from client'):
        assert client.succeed("${dig} +short A example.com @2001:db8::1").strip() == "192.0.2.2"
        assert client.succeed("${dig} +short AAAA example.com @2001:db8::1").strip() == "64:ff9b::c000:202"

      with subtest('ensure nat64 works as expected'):
        client.succeed("${curl} -sI http://example.com | grep 'HTTP/1.1 200 OK'")
    '';
}
