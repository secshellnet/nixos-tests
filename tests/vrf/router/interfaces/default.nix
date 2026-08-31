{
  imports = [
    ./loopback.nix

    ./eth1-lan.nix

    ./vrf-public.nix
    ./vrf-downstream1.nix
    ./vrf-tenant1.nix
  ];

  networking = {
    iproute2.enable = true;
    ifstate.enable = true;
  };
}
