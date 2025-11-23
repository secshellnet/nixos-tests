{ ... }:
{
  name = "bgp-md5";

  defaults = {
    networking.firewall.allowedTCPPorts = [ 179 ];
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
      services.frr = {
        bgpd.enable = true;
        config = ''
          router bgp 64496
            no bgp ebgp-requires-policy
            no bgp default ipv4-unicast
            bgp router-id 192.0.2.1

            neighbor 192.0.2.2 remote-as 64497
            neighbor 192.0.2.2 password s3cr3tPassw0rd
            neighbor 2001:db8::2 remote-as 64497
            neighbor 2001:db8::2 password s3cr3tPassw0rd

            address-family ipv4 unicast
              neighbor 192.0.2.2 activate
            exit-address-family

            address-family ipv6 unicast
              neighbor 2001:db8::2 activate
            exit-address-family
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
      services.bird = {
        enable = true;
        config = ''
          log syslog all;
          router id 192.0.2.2;

          # The Device protocol is not a real routing protocol. It does not generate any
          # routes and it only serves as a module for getting information about network
          # interfaces from the kernel. It is necessary in almost any configuration.
          protocol device {
            scan time 10;
          }

          # The Kernel protocol is not a real routing protocol. Instead of communicating
          # with other routers in the network, it performs synchronization of BIRD
          # routing tables with the OS kernel. One instance per table.
          protocol kernel kernel4 {
            ipv4 {
              import none;
              export all;
            };
          }
          protocol kernel kernel6 {
            ipv6 {
              import none;
              export all;
            };
          }

          # Static routes (Again, there can be multiple instances, for different address
          # families and to disable/enable various groups of static routes on the fly).
          protocol static static4 {
            ipv4;
          }
          protocol static static6 {
            ipv6;
          }

          protocol bgp a_v4 {
            local as 64497;
            neighbor 192.0.2.1 as 64496;

            authentication md5;
            password "s3cr3tPassw0rd";

            ipv4 {
              import all;
              export all;
            };
          }

          protocol bgp a_v6 {
            local as 64497;
            neighbor 2001:db8::1 as 64496;

            authentication md5;
            password "s3cr3tPassw0rd";

            ipv6 {
              import all;
              export all;
            };
          }
        '';
      };
    };
  };

  testScript = ''
    start_all()

    a.wait_for_unit("network.target")
    b.wait_for_unit("network.target")

    a.wait_for_unit("frr.service")
    b.wait_for_unit("bird.service")

    a.wait_until_succeeds("vtysh -c 'show bgp ipv4 summary' | grep '192.0.2.2.*0\\s*0\\s*N/A'")
    b.wait_until_succeeds("birdc show protocols | grep 'a_v4.*Established'")

    # IPv6 DAD might need some time to complete for the local link address, which is required by frr
    a.wait_until_succeeds("vtysh -c 'show bgp ipv6 summary' | grep '2001:db8::2.*0\\s*0\\s*N/A'")
    b.wait_until_succeeds("birdc show protocols | grep 'a_v6.*Established'")
  '';
}
