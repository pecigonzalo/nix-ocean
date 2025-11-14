{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./nix.nix
  ];

  # Use systemd-boot (modern, lightweight UEFI bootloader)
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5; # Keep last 5 generations
  };
  boot.loader.efi.canTouchEfiVariables = true;

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

  # State version
  system.stateVersion = "24.05";
}
