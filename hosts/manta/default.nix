# NixOS configuration for the "manta" host
# manta: Personal server hosted in Hetzner
# hardware: Intel i7-3770, 32GB, 4x6TB HDD
{
  pkgs,
  secrets,
  ...
}:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./monitoring.nix
    ./users
    ./docker
    ./performance.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
    ../../modules/common/server-tools.nix
  ];

  networking.hostName = "manta";

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/e3d3f7e9-f687-4bf3-a272-fc64bf7835b2";
    fsType = "ext4";
  };

  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/72099223-8129-47b2-b56f-7e8ed76f6024";
    fsType = "ext4";
  };

  age.secrets.tailscale = {
    file = "${secrets}/tailscale.age";
    owner = "root";
    group = "root";
    mode = "400";
  };

  boot = {
    swraid.enable = true;
    loader = {
      systemd-boot.enable = false;
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        efiSupport = false;
        devices = [
          "/dev/sda"
          "/dev/sdb"
          "/dev/sdc"
          "/dev/sdd"
        ];
      };
    };
    initrd.kernelModules = [ "i915" ];
    binfmt.emulatedSystems = [ "aarch64-linux" ];
    swraid.mdadmConf = ''
      HOMEHOST <ignore>
      MAILADDR root
    '';
    tmp = {
      cleanOnBoot = true;
      useTmpfs = true;
    };
  };

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      vaapiIntel
      libvdpau-va-gl
      intel-media-driver
    ];
  };
  environment.variables.VDPAU_DRIVER = "va_gl";

  ocean = {
    nix = {
      gcSchedule = "12:50";
      gcOptions = "--delete-older-than 15d";
      optimiseSchedule = [ "12:20" ];
    };

    performance.cpuGovernor = "ondemand";
  };

  environment.systemPackages = with pkgs; [
    sshuttle
    procs
    gping
    rdfind
  ];

  programs.fish.enable = true;

  # State version
  system.stateVersion = "25.05";
}
