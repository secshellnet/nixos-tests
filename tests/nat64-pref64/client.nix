{ lib, pkgs, ... }:
{
  virtualisation.interfaces.eth1 = {
    vlan = 2;
    assignIP = false;
  };

  networking = {
    interfaces.eth1 = { };
    nameservers = [ "2001:db8::1" ];
  };

  services.clatd = {
    enable = true;
    settings = {
      plat-prefix = "64:ff9b::/96";
      debug = 1;
    };
  };

  systemd.services.clatd.preStart =
    let
      ip = lib.getExe' pkgs.iproute2 "ip";
      jq = lib.getExe pkgs.jq;
    in
    ''
      while [ $(${ip} -j -6 address show eth1 | ${jq} '.[] | .addr_info | map(select((.scope == "global") and (.tentative == true))) | length') -ne 0 ]
      do
        sleep 0.1
      done
    '';
}
