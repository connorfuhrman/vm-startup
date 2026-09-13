{
  description = "Determinate Nix OCI container image";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f {
            inherit system;
            pkgs = nixpkgs.legacyPackages.${system};
            determinateNix = determinate.inputs.nix.packages.${system}.default;
            determinateNixd = determinate.packages.${system}.default;
          }
        );
    in
    {
      packages = forAllSystems (
        {
          pkgs,
          determinateNix,
          determinateNixd,
          ...
        }:
        let
          container = import ./nix/container.nix {
            inherit pkgs determinateNix determinateNixd;
            nixConfPath = ./nix/nix.conf;
          };
        in
        {
          container = container;
          default = container;
        }
      );

      formatter = forAllSystems (
        { pkgs, ... }:
        if pkgs ? nixfmt-rfc-style then pkgs.nixfmt-rfc-style else pkgs.nixfmt
      );

      checks = forAllSystems (
        { system, ... }:
        {
          container-image = self.packages.${system}.container;
        }
      );
    };
}
