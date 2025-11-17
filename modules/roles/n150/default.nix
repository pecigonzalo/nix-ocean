{
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
}
