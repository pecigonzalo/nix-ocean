{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  hardware.ksm = {
    enable = true;
    sleep = 20;
  };

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

  services.thermald.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
    priority = 10;
  };

  # Enable SSD trimming for better disk performance and longevity
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  environment.systemPackages =
    with pkgs;
    map lib.lowPrio [
      bluez
    ];
}
