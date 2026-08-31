{
  lib,
  pkgs,
  ...
}:
{
  name = "nat64-pref64";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.enable = false;
    };
  };

  nodes = {
    server = import ./server.nix { inherit pkgs; };
    nat64gw = import ./nat64gw.nix;
    client = import ./client.nix { inherit lib pkgs; };
  };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          curl
          dig
          tcpdump
          pwru
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
      jq = lib.getExe pkgs.jq;
    in
    ''
      start_all()

      for m in [server, nat64gw, client]:
        m.wait_for_unit("network.target")

      server.wait_for_unit("nginx.service")
      server.wait_for_unit("bind.service")
      nat64gw.wait_for_unit("dnsmasq.service")
      nat64gw.wait_for_unit("jool-nat64-eth2.service")
      nat64gw.wait_for_unit("radvd.service")

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

      with subtest('ensure dns server on nat64gw works as expected'):
        assert nat64gw.succeed("${dig} +short A example.com @2001:db8::1").strip() == "192.0.2.2"
        assert nat64gw.succeed("${dig} +short AAAA example.com @2001:db8::1").strip() == ""

      with subtest('ensure ipv6 network between gateway and client is working'):
        client.wait_until_succeeds("""
          ip -j -6 a sh eth1 | \
            ${jq} -r '.[] | .addr_info | .[] | select((.family == "inet6") and .dynamic == true) | .local' | \
              grep 2001:db8
        """)
        client.succeed("ping -6 -c 1 2001:db8::1")

      with subtest('ensure dns works as expected from client, and there is no aaaa record'):
        assert client.succeed("${dig} +short A example.com @2001:db8::1").strip() == "192.0.2.2"
        assert client.succeed("${dig} +short AAAA example.com @2001:db8::1").strip() == ""

      with subtest('ensure nat64 works as expected'):
        client.wait_until_succeeds("ping -6 -c 1 64:ff9b::192.0.2.2")
        client.wait_until_succeeds("${curl} -sI http://[64:ff9b::192.0.2.2] | grep 'HTTP/1.1 200 OK'")

      # clat needs to be started after slaac, restarting it now should be sufficient
      client.succeed("systemctl restart clatd")
      client.wait_for_unit("clatd.service")
      client.wait_until_succeeds("ip link show clat")

      with subtest('ensure clat uses correct address from ipv4 service continuity prefix'):
        client.wait_until_succeeds("""
          ip -j -4 address sh clat | ${jq} -e -r '.[].addr_info.[].local == "192.0.0.1"'
        """)

      with subtest('ensure clat created a ipv4 default route to attract ipv4 traffic'):
        client.wait_until_succeeds("""
          ip -4 -j route show default | ${jq} -e -r '.[].dev == "clat"'
        """)

      # for debugging purpose:
      print(client.succeed("${curl} -v http://example.com"))
      # connect to 192.0.2.2 port 80 from 192.0.0.1 port 37636 failed: No route to host

      with subtest('ensure clat works as expected'):
        client.succeed("${curl} -sI http://example.com | grep 'HTTP/1.1 200 OK'")
    '';
}
