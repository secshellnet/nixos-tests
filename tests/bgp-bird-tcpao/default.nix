{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  name = "bird-bgp-tcpao";

  defaults = {
    networking = {
      useDHCP = false;
      firewall.allowedTCPPorts = [ 179 ];
    };

    boot.kernelPackages = pkgs.linuxPackagesFor (
      pkgs.linux.override {
        structuredExtraConfig = with lib.kernel; {
          TCP_AO = yes;
        };
      }
    );
  };

  nodes = {
    a = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.1";
            prefixLength = 30;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::1";
            prefixLength = 64;
          }
        ];
      };
      services.bird = {
        enable = true;
        config = ''
          log syslog all;
          router id 192.0.2.1;

          protocol device {
            scan time 10;
          }

          protocol kernel kernel4 {
            ipv4 {
              export all;
            };
          }

          protocol kernel kernel6 {
            ipv6 {
              export all;
            };
          }

          protocol static static4 {
            ipv4;
          }

          protocol static static6 {
            ipv6;
          }

          protocol bgp b4 {
            local as 64496;
            neighbor 192.0.2.2 as 64497;

            authentication ao;
            keys {
              key {
                id 0;
                secret "321legacy";
                algorithm hmac sha256;
                preferred;
              };
            };

            ipv4 {
              import all;
              export all;
            };
          }

          protocol bgp b6 {
            local as 64496;
            neighbor 2001:db8::2 as 64497;

            authentication ao;
            keys {
              key {
                id 0;
                secret "hello123";
                algorithm hmac sha256;
                preferred;
              };
            };

            ipv6 {
              import all;
              export all;
            };
          }
        '';
      };
    };
    b = {
      networking.interfaces.eth1 = {
        ipv4.addresses = [
          {
            address = "192.0.2.2";
            prefixLength = 30;
          }
        ];
        ipv6.addresses = [
          {
            address = "2001:db8::2";
            prefixLength = 64;
          }
        ];
      };
      imports = [ inputs.bird.nixosModules.default ];
      services.bird = {
        enable = true;
        package = lib.mkForce pkgs.bird3;
        config = ''
          log syslog all;
        '';
        routerId = "192.0.2.2";
        templates.bgp.a = ''
          local as 64497;
          authentication ao;
        '';
        protocols = {
          device."" = ''
            scan time 10;
          '';
          kernel = {
            kernel4 = ''
              ipv4 {
                export all;
              };
            '';
            kernel6 = ''
              ipv6 {
                export all;
              };
            '';
          };
          static = {
            static4 = ''
              ipv4;
            '';
            static6 = ''
              ipv6;
            '';
          };
          bgp = {
            "a4 from a" = ''
              neighbor 192.0.2.1 as 64496;

              keys {
                key {
                  id 0;
                  secret "321legacy";
                  algorithm hmac sha256;
                  preferred;
                };
              };

              ipv4 {
                import all;
                export all;
              };
            '';
            "a6 from a" = ''
              neighbor 2001:db8::1 as 64496;

              keys {
                key {
                  id 0;
                  secret "hello123";
                  algorithm hmac sha256;
                  preferred;
                };
              };

              ipv6 {
                import all;
                export all;
              };
            '';
          };
        };
      };
    };
  };

  testScript = ''
    start_all()

    for m in [a, b]:
      m.wait_for_unit("network.target")
      m.wait_for_unit("bird.service")

    a.wait_until_succeeds("birdc show protocols 2>&1 | grep 'b4.*Established'")
    b.wait_until_succeeds("birdc show protocols 2>&1 | grep 'a4.*Established'")

    a.wait_until_succeeds("birdc show protocols 2>&1 | grep 'b6.*Established'")
    b.wait_until_succeeds("birdc show protocols 2>&1 | grep 'a6.*Established'")
  '';
}
