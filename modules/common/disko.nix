# UEFI-only disk configuration for systemd-boot
{ lib, ... }:
let
  # Common mount options for SSD subvolumes
  ssdOpts = [
    "noatime"
    "compress=zstd"
    "ssd"
    "discard=async"
    "space_cache=v2"
  ];

  # List of subvolumes: name and mountpoint
  subvolumes = [
    {
      name = "@root";
      mountpoint = "/";
    }
    {
      name = "@home";
      mountpoint = "/home";
    }
    {
      name = "@nix";
      mountpoint = "/nix";
    }
    {
      name = "@log";
      mountpoint = "/var/log";
    }
    # Swap subvolume is special (CoW disabled)
    {
      name = "@swap";
      mountpoint = "/swap";
      mountOptions = ssdOpts ++ [ "nodatacow" ];
    }
  ];
in
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          # --- EFI System Partition ---
          EFI = {
            size = "512M";
            type = "ef00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          # --- Btrfs Root Partition ---
          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              mountpoint = "/";
              subvolumes = builtins.listToAttrs (
                map (subvol: {
                  name = subvol.name;
                  value = {
                    mountpoint = subvol.mountpoint;
                    mountOptions = subvol.mountOptions or ssdOpts;
                  };
                }) subvolumes
              );
            };
          };
        };
      };
    };
    nodev = {
      "/tmp" = {
        fsType = "tmpfs";
        mountOptions = [
          "size=2G"
        ];
      };
    };
  };
}
