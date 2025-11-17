{
  lib,
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
  };
}
