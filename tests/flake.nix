{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";

    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake
      { inherit inputs; }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        perSystem = { pkgs, lib, system, ... }:
          let
            mkSystem = inInitrd: inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                ../module.nix
                {
                  boot.initrd.systemd.enable = false;
                  system.stateVersion = "25.05";
                  preservation = {
                    enable = true;
                    preserveAt."/state".files = [
                      { file = "/etc/preserved"; inherit inInitrd; }
                    ];
                  };
                }
              ];
            };
            withInitrdEntry = mkSystem true;
            stage2Only = mkSystem false;
            fires = system: lib.any (a: !a.assertion && lib.hasInfix "inInitrd" a.message)
              system.config.assertions;
          in
          {
            checks = {
              default = pkgs.nixosTest (import ./basic.nix pkgs);
              no-initrd = pkgs.nixosTest (import ./no-initrd.nix pkgs);
              assertion = pkgs.runCommand "preservation-assertion" { }
                (assert fires withInitrdEntry && !fires stage2Only; "touch $out");
              firstboot = pkgs.nixosTest (import ./firstboot.nix pkgs);
              verity-image = pkgs.nixosTest (import ./appliance-image-verity.nix pkgs);
            };
          };
      };
}
