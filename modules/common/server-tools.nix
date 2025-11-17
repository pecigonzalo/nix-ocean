{
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    map lib.lowPrio [
      gitMinimal
      neovim
      curl
      dig
      iftop
      iperf3
      mtr
      tcpdump
      traceroute
      usbutils
      pciutils
      fastfetch
    ];

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
}
