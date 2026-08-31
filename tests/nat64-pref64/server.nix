{ pkgs, ... }:
{
  virtualisation.interfaces.eth1 = {
    vlan = 1;
    assignIP = false;
  };
  networking.interfaces.eth1 = {
    ipv4.addresses = [
      {
        address = "192.0.2.2";
        prefixLength = 24;
      }
    ];
  };
  services.nginx = {
    enable = true;
    virtualHosts."example.com".locations."/".return = "200";
  };

  # public dns server
  services.resolved.enable = false;
  services.bind = {
    enable = true;
    cacheNetworks = [ "0.0.0.0/0" ];
    # first line (comment) is to align config
    extraOptions = ''
      #
        recursion yes;
        auth-nxdomain no;
        dnssec-validation no;
    '';
    zones."example.com" = {
      master = true;
      file = pkgs.writeText "zone-example.com.conf" ''
        $TTL 1
        @     IN    SOA       example.com.          zonemaster.example.com. (
                                                      2023013100 ; serial number
                                                      86400      ; refresh: 1d
                                                      900        ; update retry: 15m
                                                      604800     ; expiry: 1w
                                                      3600 )     ; negative caching 1h

        @     IN    NS        example.com.
        @     IN    A         192.0.2.2

      '';
    };
  };
  networking.nameservers = [ "127.0.0.1" ];
}
