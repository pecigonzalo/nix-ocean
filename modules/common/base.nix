{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkIf mkOption types;
  bootCfg = config.ocean.boot;
in
{
  imports = [
    ./nix.nix
  ];

  options.ocean.boot = {
    loader = mkOption {
      type = types.enum [
        "systemd-boot"
        "grub"
      ];
      default = "systemd-boot";
      description = "Boot loader to use on the host.";
    };

    systemdBootConfigurationLimit = mkOption {
      type = types.int;
      default = 5;
      description = "Number of generations to keep in systemd-boot.";
    };

    efiCanTouchVariables = mkOption {
      type = types.bool;
      default = true;
      description = "Whether the system can modify EFI variables.";
    };

    grubDevices = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Devices to install GRUB to when using the GRUB loader.";
    };

    grubEfiSupport = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to build GRUB with EFI support.";
    };
  };

  config = {
    # Use systemd-boot (modern, lightweight UEFI bootloader)
    boot.loader.systemd-boot = mkIf (bootCfg.loader == "systemd-boot") {
      enable = true;
      configurationLimit = bootCfg.systemdBootConfigurationLimit; # Keep last N generations
    };
    boot.loader.efi.canTouchEfiVariables = bootCfg.efiCanTouchVariables;

    boot.loader.grub = mkIf (bootCfg.loader == "grub") {
      enable = true;
      efiSupport = bootCfg.grubEfiSupport;
      devices = bootCfg.grubDevices;
    };

    # Modern OpenSSH configuration
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "prohibit-password";
        # Modern ciphers and key exchange algorithms
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group16-sha512"
          "diffie-hellman-group18-sha512"
        ];
      };
      # Automatically remove stale sockets
      startWhenNeeded = false; # Always on for servers
    };

    # Firmware updates
    services.fwupd.enable = true;

    # Hardware support
    hardware.enableRedistributableFirmware = true;
    hardware.firmware = with pkgs; [
      linux-firmware
      wireless-regdb
    ];

    # Modern Bluetooth configuration
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
        };
        Policy = {
          AutoEnable = true;
        };
      };
    };

    # Essential packages with priority handling
    environment.systemPackages =
      with pkgs;
      map lib.lowPrio [
        # Version control
        gitMinimal

        # Editors
        neovim

        # Network tools
        bluez
        curl
        dig
        iftop
        iperf3
        mtr
        tcpdump
        traceroute

        # System tools
        usbutils
        pciutils
      ];

    # Modern htop configuration
    programs.htop = {
      enable = true;
      settings = {
        hide_kernel_threads = true;
        hide_userland_threads = false;
        column_meters_0 = "AllCPUs Memory Zram Swap";
        column_meter_modes_0 = "1 1 1 1";
        column_meters_1 = "Tasks LoadAverage DiskIO NetworkIO Uptime";
        column_meter_modes_1 = "2 2 2 2 2";
      };
    };
  };
}
