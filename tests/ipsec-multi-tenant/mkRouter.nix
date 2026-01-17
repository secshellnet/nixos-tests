{
  outsideVid ? 2,
  outsideIp ? "198.51.100.1",
  outsidePeer ? "198.51.100.2",
  tenant1Vid ? 3,
  tenant1Ip ? "192.168.0.1/24",
  tenant1Net ? "192.168.0.0/24",
  tenant2Vid ? 4,
  tenant2Ip ? "192.168.1.1/24",
  tenant2Net ? "192.168.1.0/24",
}:
{
  # enable ip forwarding
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  virtualisation.interfaces =
    builtins.mapAttrs
      (_: vlan: {
        inherit vlan;
        assignIP = false;
      })
      {
        eth1 = outsideVid;
        eth2 = tenant1Vid;
        eth3 = tenant2Vid;
      };

  networking.ifstate = {
    enable = true;
    settings = {
      interfaces = {
        eth1 = {
          addresses = [ "${outsideIp}/30" ];
          link = {
            state = "up";
            kind = "physical";
          };
        };

        # first tenant VRF
        tenant1 = {
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
            xfrm_link = "eth1";
            xfrm_if_id = 1;
            master = "tenant1";
          };
        };
        eth2 = {
          addresses = [ tenant1Ip ];
          link = {
            state = "up";
            kind = "physical";
            master = "tenant1";
          };
        };

        # second tenant VRF
        tenant2 = {
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
            xfrm_link = "eth1";
            xfrm_if_id = 2;
            master = "tenant2";
          };
        };
        eth3 = {
          addresses = [ tenant2Ip ];
          link = {
            state = "up";
            kind = "physical";
            master = "tenant2";
          };
        };
      };
      routing = {
        # add default routes into vpn
        routes = [
          {
            to = "0.0.0.0/0";
            dev = "ipsec-tenant1";
            table = 101;
          }
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
          local_addrs = [ outsideIp ];
          remote_addrs = [ outsidePeer ];

          if_id_in = "1";
          if_id_out = "1";

          local."0".auth = "psk";
          remote."0".auth = "psk";

          children.tenant1 = {
            local_ts = [ tenant1Net ];
            remote_ts = [ "0.0.0.0/0" ];
          };
        };
        tenant2 = {
          local_addrs = [ outsideIp ];
          remote_addrs = [ outsidePeer ];

          if_id_in = "2";
          if_id_out = "2";

          local."0".auth = "psk";
          remote."0".auth = "psk";

          children.tenant2 = {
            local_ts = [ tenant2Net ];
            remote_ts = [ "0.0.0.0/0" ];
          };
        };
      };
    };
  };
}
