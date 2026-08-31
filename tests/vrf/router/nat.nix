{
  networking.nftables = {
    enable = true;
    tables.nat = {
      enable = true;
      name = "nat";
      family = "ip";
      content = ''
        chain prerouting {
          type nat hook prerouting priority dstnat; policy accept;
        }

        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
        }
      '';
    };
  };
}
