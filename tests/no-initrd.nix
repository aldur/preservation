pkgs:
{
  name = "preservation-no-initrd";

  nodes.machine =
    { lib, ... }:
    {
      imports = [ ../module.nix ];

      boot.initrd.systemd.enable = false;
      users.users.alice.isNormalUser = true;

      preservation = {
        enable = true;
        preserveAt."/state" = {
          files = [ "/etc/preserved" ];
          users.alice.directories = [
            { directory = ".local/share/keyrings"; mode = "0700"; }
          ];
        };
      };

      virtualisation = {
        memorySize = 2048;
        emptyDiskImages = [ 23 ];
        fileSystems = {
          "/" = lib.mkForce {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=0755" ];
          };
          "/state" = {
            device = "/dev/vdb";
            fsType = "ext4";
            # Formatting uses systemd-makefs in stage 2, after the scripted initrd.
            autoFormat = true;
          };
        };
      };
    };

  testScript =
    { ... }:
    # python
    ''
      def check_ownership():
          for prefix in ["", "/state"]:
              for relative in ["", "/.local", "/.local/share", "/.local/share/keyrings"]:
                  path = f"{prefix}/home/alice{relative}"
                  owner = machine.succeed(f"stat -c %U {path}").strip()
                  t.assertEqual(owner, "alice", f"unexpected owner of {path}")

      machine.start(allow_reboot=True)
      machine.wait_for_unit("multi-user.target")

      with subtest("Stage-2 mounts and user parents are prepared without systemd initrd"):
          machine.succeed("findmnt --type tmpfs /")
          machine.succeed("mountpoint /home/alice/.local/share/keyrings")
          machine.succeed("mountpoint /etc/preserved")
          check_ownership()

      with subtest("Only preserved state survives a reboot"):
          machine.succeed("runuser -u alice -- sh -c 'echo keyring > /home/alice/.local/share/keyrings/marker'")
          machine.succeed("echo preserved > /etc/preserved")
          machine.succeed("echo volatile > /etc/not-preserved")
          machine.reboot()
          machine.wait_for_unit("multi-user.target")
          machine.succeed("test $(cat /home/alice/.local/share/keyrings/marker) = keyring")
          machine.succeed("test $(cat /etc/preserved) = preserved")
          machine.succeed("test ! -e /etc/not-preserved")
          check_ownership()

      machine.shutdown()
    '';
}
