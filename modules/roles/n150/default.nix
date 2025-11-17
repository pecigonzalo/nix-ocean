{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./disko.nix
  ];

  hardware.ksm = {
    enable = true;
    sleep = 20;
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
