{
  lib,
  pkgs,
  ...
}:
{
  name = "vrf";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.enable = false;
    };
  };

  nodes = {
    router = import ./router;

    upstream = import ./upstream.nix;

    ds1r = import ./t1r.nix;
    ds1c = import ./tenantClient.nix {
      vlan = 5;
      ipv4 = "198.51.100.99";
      ipv4gw = "198.51.100.65";
      ipv4cidr = 26;
      ipv6 = "2001:db8:beef:20::c";
    };
    t1a = import ./tenantClient.nix {
      vlan = 4;
      ipv4 = "10.0.10.10";
      ipv4gw = "10.0.10.1";
      ipv6 = "2001:db8:10::a";
    };
    t1b = import ./tenantClient.nix {
      vlan = 4;
      ipv4 = "10.0.10.11";
      ipv4gw = "10.0.10.1";
      ipv6 = "2001:db8:10::b";
    };
  };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          nftables
          tcpdump
        ];
      })
      [
        "router"
        "upstream"
        "ds1r"
        "ds1c"
        "t1a"
        "t1b"
      ]
  );
  # think about ping4/ping6 jobs every three seconds on tXY when in interactive mode

  testScript = ''
    start_all()

    router.wait_for_unit("network.target")
    router.wait_for_unit("frr.service")
    upstream.wait_for_unit("bird.service")

    with subtest("try to ping internet from clients in tenant vrf's"):
      for m in [ ds1c, t1a, t1b ]:
        m.succeed("ping -c 1 203.0.113.100")
        m.succeed("ping -c 1 3fff:ffff::100")
  '';
}
