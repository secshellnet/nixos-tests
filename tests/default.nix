{
  inputs,
  system,
  interactive ? false,
}:
let
  inherit (inputs) nixpkgs;
  inherit (nixpkgs) lib;

  pkgs = import nixpkgs { inherit system; };

  tests = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (name: type: type == "directory" && !lib.hasPrefix "_" name))
    builtins.attrNames
  ];
in
builtins.listToAttrs (
  map (name: {
    inherit name;
    value =
      let
        test = import ./${name} {
          inherit
            inputs
            lib
            pkgs
            ;
        };
        driver = pkgs.testers.runNixOSTest (
          lib.recursiveUpdate {
            interactive = {
              sshBackdoor.enable = true;
              nodes = lib.listToAttrs (
                map (name: {
                  inherit name;
                  value.virtualisation.graphics = false;
                }) (builtins.attrNames test.nodes)
              );
            };
          } test
        );
      in
      if interactive then
        {
          type = "app";
          program = "${driver.driverInteractive}/bin/nixos-test-driver";
        }
      else
        driver;
  }) tests
)
