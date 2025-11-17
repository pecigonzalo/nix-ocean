{
  lib,
  pkgs,
  ...
}:
{
  environment.systemPackages =
    with pkgs;
    map lib.lowPrio [
      # Essential tools
      gitMinimal
      curl
      wget
      binutils
      findutils
      coreutils
      # Disk tools
      du-dust
      # Networking tools
      dnsutils
      dig
      drill
      ripgrep
      iftop
      iotop-c
      iperf3
      mtr
      tcpdump
      traceroute
      netcat-gnu
      nmap
      ngrep
      socat
      # Backup
      restic
      # Hardware info tools
      usbutils
      pciutils
      fastfetch
    ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
  };

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
