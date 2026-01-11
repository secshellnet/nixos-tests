{ lib, pkgs, ... }:
{
  name = "ipsec-multi-tenant";

  defaults = {
    networking.firewall.enable = false;
    virtualisation.interfaces = {
      outside = {
        vlan = 2;
        assignIP = false;
      };
      trunk = {
        vlan = 20;
        assignIP = false;
      };
    };
  };

  nodes = {
    /*
      machine1 = {
        networking.ifstate = {
          enable = true;
          settings = {
            interfaces = {
              # external interface for IPsec termination
              outside = {
                addresses = [ "198.51.100.1/30" ];
                link = {
                  state = "up";
                  kind = "physical";
                };
              };

              # inside base interface
              trunk = {
                link = {
                  kind = "physical";
                  state = "up";
                };
              };

              # first tenant VRF
              vrf-tenant1 = {
                link = {
                  state = "up";
                  kind = "vrf";
                  vrf_table = 101;
                };
              };
              ipsec-tenant1 = {
                link = {
                  state = "up";
                  kind = "xfrm";
                  xfrm_link = "outside";
                  xfrm_if_id = 1;
                  master = "vrf-tenant1";
                };
              };
              inside-tenant1 = {
                addresses = [ "192.0.2.1/24" ];
                link = {
                  state = "up";
                  kind = "vlan";
                  link = "trunk";
                  vlan_id = 41;
                  master = "vrf-tenant1";
                };
              };

              # second tenant VRF
              vrf-tenant2 = {
                link = {
                  state = "up";
                  kind = "vrf";
                  vrf_table = 102;
                };
              };
              ipsec-tenant2 = {
                link = {
                  state = "up";
                  kind = "xfrm";
                  xfrm_link = "outside";
                  xfrm_if_id = 2;
                  master = "vrf-tenant2";
                };
              };
              inside-tenant2 = {
                addresses = [ "192.0.2.1/24" ];
                link = {
                  state = "up";
                  kind = "vlan";
                  link = "trunk";
                  vlan_id = 42;
                  master = "vrf-tenant2";
                };
              };
            };
            routing = {
              routes = [
                # first tenant VRF: add default route into vpn
                {
                  to = "0.0.0.0/0";
                  dev = "ipsec-tenant1";
                  table = 101;
                }

                # second tenant VRF: add default route into vpn
                {
                  to = "0.0.0.0/0";
                  dev = "ipsec-tenant2";
                  table = 102;
                }
              ];
            };
          };
        };

        services.strongswan-swanctl = {
          enable = true;
          swanctl = {
            secrets.ike.default.secret = "012345678ABCDEF";
            connections = {
              tenant1 = {
                local_addrs = [ "198.51.100.1" ];
                remote_addrs = [ "198.51.100.2" ];

                if_id_in = "1";
                if_id_out = "1";

                local."machine2".auth = "psk";
                remote."machine1".auth = "psk";

                children.tenant1 = {
                  local_ts = [ "192.0.2.0/24" ];
                  remote_ts = [ "0.0.0.0/0" ];
                };
              };
              tenant2 = {
                local_addrs = [ "198.51.100.1" ];
                remote_addrs = [ "198.51.100.2" ];

                if_id_in = "2";
                if_id_out = "2";

                local."machine2".auth = "psk";
                remote."machine1".auth = "psk";

                children.tenant1 = {
                  local_ts = [ "192.0.2.0/24" ];
                  remote_ts = [ "0.0.0.0/0" ];
                };
              };
            };
          };
        };
      };
    */
    machine2 = {
      networking.ifstate = {
        enable = true;
        settings = {
          interfaces = {
            # external interface for IPsec termination
            outside = {
              addresses = [ "198.51.100.2/30" ];
              link = {
                state = "up";
                kind = "physical";
              };
            };

            # inside base interface
            trunk = {
              link = {
                kind = "physical";
                state = "up";
              };
            };

            # first tenant VRF
            vrf-tenant1 = {
              link = {
                state = "up";
                kind = "vrf";
                vrf_table = 101;
              };
            };
            ipsec-tenant1 = {
              link = {
                state = "up";
                kind = "xfrm";
                xfrm_link = "outside";
                xfrm_if_id = 1;
                master = "vrf-tenant1";
              };
            };
            inside-tenant1 = {
              addresses = [ "192.0.2.1/24" ];
              link = {
                state = "up";
                kind = "vlan";
                link = "trunk";
                vlan_id = 41;
                master = "vrf-tenant1";
              };
            };

            # second tenant VRF
            vrf-tenant2 = {
              link = {
                state = "up";
                kind = "vrf";
                vrf_table = 102;
              };
            };
            ipsec-tenant2 = {
              link = {
                state = "up";
                kind = "xfrm";
                xfrm_link = "outside";
                xfrm_if_id = 2;
                master = "vrf-tenant2";
              };
            };
            inside-tenant2 = {
              addresses = [ "192.0.2.1/24" ];
              link = {
                state = "up";
                kind = "vlan";
                link = "trunk";
                vlan_id = 42;
                master = "vrf-tenant2";
              };
            };
          };
          routing = {
            routes = [
              # first tenant VRF: add default route into vpn
              {
                to = "0.0.0.0/0";
                dev = "ipsec-tenant1";
                table = 101;
              }

              # second tenant VRF: add default route into vpn
              {
                to = "0.0.0.0/0";
                dev = "ipsec-tenant2";
                table = 102;
              }
            ];
          };
        };
      };
      /*
        services.strongswan-swanctl = {
          enable = true;
          swanctl = {
            secrets.ike.default.secret = "012345678ABCDEF";
            connections = {
              tenant1 = {
                local_addrs = [ "198.51.100.2" ];
                remote_addrs = [ "198.51.100.1" ];

                if_id_in = "1";
                if_id_out = "1";

                local."machine2".auth = "psk";
                remote."machine1".auth = "psk";

                children.tenant1 = {
                  local_ts = [ "192.0.2.0/24" ];
                  remote_ts = [ "0.0.0.0/0" ];
                };
              };
              tenant2 = {
                local_addrs = [ "198.51.100.2" ];
                remote_addrs = [ "198.51.100.1" ];

                if_id_in = "2";
                if_id_out = "2";

                local."machine2".auth = "psk";
                remote."machine1".auth = "psk";

                children.tenant1 = {
                  local_ts = [ "192.0.2.0/24" ];
                  remote_ts = [ "0.0.0.0/0" ];
                };
              };
            };
          };
        };
      */
    };
  };

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

      machine1.succeed("${nc} -lvnp 4444 &> nc.txt &")
      machine2.succeed("${nc} -w0 machine1 4444 <<< s3cr3t")

      assert "ESTABLISHED" in machine1.succeed("${lib.getExe' pkgs.strongswan "ipsec"} status"), \
        "ipsec sa not established"

      assert "IKE_SAs: 1 total" in machine2.succeed("${lib.getExe pkgs.strongswan} --stats"), \
        "ipsec sa not established"

      assert "s3cr3t" in machine1.succeed("cat nc.txt"), \
        "netcat log file doesn't contain secret message"
    '';
}
