{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    bird.url = "github:NuschtOS/bird.nix";
    ifstate.url = "git+https://codeberg.org/liske/ifstate";
  };
  outputs =
    { ... }@inputs:
    let
      inherit (inputs.nixpkgs) lib;
      defaultSystems = [
        "x86_64-linux"
        "x86_64-darwin"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      eachDefaultSystem = lib.genAttrs defaultSystems;
    in
    {
      formatter = eachDefaultSystem (system: inputs.nixpkgs.legacyPackages.${system}.nixfmt-tree);
      checks = eachDefaultSystem (system: import ./tests { inherit inputs system; });
      apps = eachDefaultSystem (
        system:
        import ./tests {
          inherit inputs system;
          interactive = true;
        }
      );
    };
}
