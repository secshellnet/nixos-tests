{ lib, pkgs, ... }:
{
  name = "ipsec-multi-tenant";

  defaults = {
    networking.firewall.enable = false;
  };

  nodes =
    let
      mkRouter = import ./mkRouter.nix;
    in
    {
      router1 = mkRouter { };
      router2 = mkRouter {
        outsideIp = "198.51.100.2";
        outsidePeer = "198.51.100.1";

        tenant1Vid = 5;
        tenant1Ip = "192.0.2.1/24";
        tenant1Net = "192.0.2.0/24";

        tenant2Vid = 6;
        tenant2Ip = "203.0.113.1/24";
        tenant2Net = "203.0.113.0/24";
      };
      t1client = import ./mkNode.nix {
        vlan = 3;
        ipv4 = "192.168.0.2";
        ipv4gw = "192.168.0.1";
      };
      t2client = import ./mkNode.nix {
        vlan = 4;
        ipv4 = "192.168.1.2";
        ipv4gw = "192.168.1.1";
      };
      t1server = import ./mkNode.nix {
        vlan = 5;
        ipv4 = "192.0.2.2";
        ipv4gw = "192.0.2.1";
      };
      t2server = import ./mkNode.nix {
        vlan = 6;
        ipv4 = "203.0.113.2";
        ipv4gw = "203.0.113.1";
      };
    };

  interactive.nodes = lib.listToAttrs (
    map
      (name: {
        inherit name;
        value.environment.systemPackages = with pkgs; [
          netcat-openbsd
          tcpdump
          strongswan
        ];
      })
      [
        "router1"
        "router2"
      ]
  );

  testScript = ''
    start_all()

    for m in [router1, router2]:
      m.wait_for_unit("strongswan-swanctl.service")

    with subtest("ensure ipsec is active"):
      router1.succeed("${lib.getExe' pkgs.strongswan "swanctl"} --initiate -c tenant1")
      router1.succeed("${lib.getExe' pkgs.strongswan "swanctl"} --initiate -c tenant2")

      # ${lib.getExe' pkgs.strongswan "swanctl"} --stats
      # ip xfrm policy
      # ip xfrm state

    with subtest("router can reach all connected nodes"):
      router1.succeed("ping -c 1 198.51.100.2")
      router2.succeed("ping -c 1 198.51.100.1")

      router1.succeed("ip vrf exec tenant1 ping -c 1 192.168.0.2")
      router1.succeed("ip vrf exec tenant2 ping -c 1 192.168.1.2")

      router2.succeed("ip vrf exec tenant1 ping -c 1 192.0.2.2")
      router2.succeed("ip vrf exec tenant2 ping -c 1 203.0.113.2")

    with subtest("router can reach vrf's of other router"):
      router2.succeed("ip vrf exec tenant1 ping -c 1 192.168.0.1")
      router2.succeed("ip vrf exec tenant2 ping -c 1 192.168.1.1")

      #router2.fail("ip vrf exec tenant1 ping -c 1 192.168.1.1")
      #router2.fail("ip vrf exec tenant2 ping -c 1 192.168.0.1")

      router1.succeed("ip vrf exec tenant1 ping -c 1 192.0.2.1")
      router1.succeed("ip vrf exec tenant2 ping -c 1 203.0.113.1")

      #router1.fail("ip vrf exec tenant1 ping -c 1 203.0.113.1")
      #router1.fail("ip vrf exec tenant2 ping -c 1 192.0.2.1")

    # TODO
    with subtest("t1client can reach ts1server"):
      t1client.succeed("ping -c 1 192.0.2.2")

    with subtest("t2client can reach ts2server"):
      t2client.succeed("ping -c 1 203.0.113.2")

    with subtest("t1client can not reach ts2server"):
      t1client.fail("ping -c 1 203.0.113.2")

    with subtest("t2client can not reach ts1server"):
      t2client.fail("ping -c 1 192.0.2.2")
  '';
}
