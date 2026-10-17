{ config, lib, ... }:

let
  cfg = config.preservation;

  inherit (import ./lib.nix { inherit lib; })
    getAllFiles
    getAllDirectories
    mkRegularMountUnits
    mkInitrdMountUnits
    mkRegularTmpfilesRules
    mkInitrdTmpfilesRules
    ;

  initrdEntries = lib.any (e: e.inInitrd) (
    lib.concatLists (
      lib.mapAttrsToList (_: p: getAllFiles p ++ getAllDirectories p) cfg.preserveAt
    )
  );
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = initrdEntries -> config.boot.initrd.systemd.enable;
        message = "preservation: entries with `inInitrd = true` require the systemd initrd.";
      }
    ];

    boot.initrd.systemd = {
      targets.initrd-preservation = {
        description = "Initrd Preservation Mounts";
        before = [ "initrd.target" ];
        wantedBy = [ "initrd.target" ];
      };
      tmpfiles.settings.preservation = lib.mkMerge (
        lib.flatten (lib.mapAttrsToList mkInitrdTmpfilesRules cfg.preserveAt)
      );
      mounts = lib.flatten (lib.mapAttrsToList mkInitrdMountUnits cfg.preserveAt);
    };

    systemd = {
      targets.preservation = {
        description = "Preservation Mounts";
        before = [ "sysinit.target" ];
        wantedBy = [ "sysinit.target" ];
      };
      tmpfiles.settings.preservation = lib.mkMerge (
        lib.flatten (lib.mapAttrsToList mkRegularTmpfilesRules cfg.preserveAt)
      );
      mounts = lib.flatten (lib.mapAttrsToList mkRegularMountUnits cfg.preserveAt);
    };

  };
}
