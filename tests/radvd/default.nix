{ lib, ... }:
{
  name = "radvd";

  defaults = {
    networking.interfaces.eth1 = {
      ipv4.addresses = lib.mkForce [ ];
      ipv6.addresses = lib.mkForce [ ];
    };
  };

  nodes = {
    a = {
      boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

      services.radvd = {
        enable = true;
        config = ''
          interface eth1 {
            AdvSendAdvert on;
            prefix 2001:db8:bad:c0de::/64 {
              AdvOnLink on;
              AdvAutonomous on;
            };
          };
        '';
      };
    };
    b = { };
  };

  testScript = ''
    start_all()

    a.wait_for_unit("network.target")
    b.wait_for_unit("network.target")

    a.wait_for_unit("radvd.service")

    b.wait_until_succeeds("ip -6 a sh eth1 | grep 2001:db8:bad:c0de:")

    # wait for ipv6 dad to finish (initial ! causes the exit status to be negated)
    b.wait_until_succeeds("! ip -6 a sh eth1 | grep tentative")

    print(b.succeed("ip -6 address show eth1"))
    print(b.succeed("ip -6 route"))
  '';
}
