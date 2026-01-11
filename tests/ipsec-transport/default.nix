{ lib, pkgs, ... }:
{
  name = "ipsec-transport";

  defaults = {
    networking.firewall.enable = false;
  };

  nodes = {
    machine1 = {
      services.strongswan = {
        enable = true;
        secrets = [
          (toString (
            pkgs.writeText "ipsec" ''
              : PSK 012345678ABCDEF
            ''
          ))
        ];
        connections = {
          "%default" = {
            ike = "aes256gcm16-sha384-ecp384!";
            esp = "aes256-sha256-ecp384!";
          };

          output = {
            rightsubnet = "%dynamic[tcp/4444]";
            right = "%any";
            type = "transport";
            authby = "psk";
            auto = "route";
          };

          input = {
            leftsubnet = "%dynamic[tcp/4444]";
            type = "transport";
            authby = "psk";
            auto = "route";
          };
        };
      };
    };
    machine2 = {
      services.strongswan-swanctl = {
        enable = true;
        swanctl = {
          secrets.ike.default.secret = "012345678ABCDEF";
          connections =
            let
              proposals = [ "aes256gcm16-sha384-ecp384" ];
              esp_proposals = [ "aes256-sha256-ecp384" ];
              mode = "transport";
              start_action = "trap";
            in
            {
              input = {
                inherit proposals;

                local."machine2".auth = "psk";

                remote."machine1".auth = "psk";

                children."nc4444" = {
                  local_ts = [ "dynamic[tcp/4444]" ];
                  inherit esp_proposals mode start_action;
                };
              };
              output = {
                inherit proposals;

                local."machine2".auth = "psk";

                remote."machine1".auth = "psk";
                remote_addrs = [ "%any" ];

                children."nc4444" = {
                  remote_ts = [ "dynamic[tcp/4444]" ];
                  inherit esp_proposals mode start_action;
                };
              };
            };
        };
      };
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
        "machine1"
        "machine2"
      ]
  );

  testScript =
    let
      nc = lib.getExe pkgs.netcat-openbsd;
    in
    ''
      start_all()

      for m in [machine1, machine2]:
        m.wait_for_unit("network.target")

      machine1.wait_for_unit("strongswan.service")
      machine2.wait_for_unit("strongswan-swanctl.service")

      machine1.succeed("${lib.getExe pkgs.tcpdump} -i any -n -c 5 'proto 50' > dump.txt &")

      machine1.succeed("${nc} -lvnp 4444 &> nc.txt &")
      machine2.succeed("${nc} -w0 machine1 4444 <<< s3cr3t")

      assert "ESTABLISHED" in machine1.succeed("${lib.getExe' pkgs.strongswan "ipsec"} status"), \
        "ipsec sa not established"

      assert "IKE_SAs: 1 total" in machine2.succeed("${lib.getExe pkgs.strongswan} --stats"), \
        "ipsec sa not established"

      assert "s3cr3t" in machine1.succeed("cat nc.txt"), \
        "netcat log file doesn't contain secret message"

      assert 0 == int(machine1.succeed("cat dump.txt | wc -l")), \
        "tcpdump log did not capture any esp packets - traffic not encrypted"
    '';
}
