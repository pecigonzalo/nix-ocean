{ lib, pkgs, secrets, config, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./monitoring.nix
    ./users
    ./docker
    ./nspawn.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
  ];

  networking.hostName = "manta";

  age.secrets.tailscale-key = {
    file = "${secrets}/tailscale-manta.age";
    owner = "root";
    group = "root";
    mode = "400";
  };

  # Keep the server on its long-term state version until we explicitly upgrade
  system.stateVersion = lib.mkForce "22.05";

  boot = {
    initrd.kernelModules = [ "i915" ];
    kernelParams = [
      "acpi_osi=Linux"
      "acpi=force"
      "acpi_enforce_resources=lax"
    ];
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

  hardware = {
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      extraPackages = with pkgs; [
        vaapiIntel
        libvdpau-va-gl
        intel-media-driver
      ];
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkForce "ondemand";

  # Force grub on BIOS Hetzner host instead of the default systemd-boot setup
  boot.loader = {
    systemd-boot.enable = lib.mkForce false;
    efi.canTouchEfiVariables = lib.mkForce false;
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

  environment.variables.VDPAU_DRIVER = "va_gl";

  boot.kernel.sysctl = {
    "fs.file-max" = 2097152;
    "kernel.task_delayacct" = 1;
    "net.core.default_qdisc" = "fq";
    "net.core.netdev_max_backlog" = 65536;
    "net.core.optmem_max" = 2097152;
    "net.core.rmem_default" = 524288;
    "net.core.rmem_max" = 33554432;
    "net.core.somaxconn" = 4096;
    "net.core.wmem_default" = 524288;
    "net.core.wmem_max" = 33554432;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.all.secure_redirects" = 0;
    "net.ipv4.ip_local_port_range" = "16384 65535";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_fin_timeout" = 30;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv4.tcp_keepalive_probes" = 8;
    "net.ipv4.tcp_keepalive_time" = 600;
    "net.ipv4.tcp_max_syn_backlog" = 30000;
    "net.ipv4.tcp_max_tw_buckets" = 1440000;
    "net.ipv4.tcp_mem" = "65536 131072 262144";
    "net.ipv4.tcp_wmem" = "8192 65536 16777216";
    "net.ipv4.tcp_rmem" = "8192 87380 16777216";
    "net.ipv4.tcp_mtu_probing" = 1;
    "net.ipv4.tcp_rfc1337" = 1;
    "net.ipv4.tcp_sack" = 1;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_synack_retries" = 3;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_window_scaling" = 1;
    "net.ipv4.udp_mem" = "65536 131072 262144";
    "net.ipv4.udp_rmem_min" = 16384;
    "net.ipv4.udp_wmem_min" = 16384;
    "net.netfilter.nf_conntrack_generic_timeout" = 60;
    "net.netfilter.nf_conntrack_max" = 1048576;
    "net.netfilter.nf_conntrack_tcp_timeout_established" = 1800;
    "vm.dirty_background_ratio" = 10;
    "vm.dirty_ratio" = 15;
    "vm.swappiness" = 10;
  };

  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      allowed-users = [ "@wheel" ];
      trusted-users = [ "@wheel" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = lib.mkForce "12:50";
      options = lib.mkForce "--delete-older-than 15d";
    };
    optimise = {
      automatic = true;
      dates = lib.mkForce [ "12:20" ];
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowInsecure = false;
    allowUnsupportedSystem = true;
    allowBroken = false;
  };

  services.fwupd.enable = true;

  programs = {
    neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
    };
    fish.enable = true;
    tmux.enable = true;
  };

  environment.systemPackages = with pkgs; [
    htop
    nmap
    iotop
    iotop-c
    ngrep
    neofetch
    netcat-gnu
    wget
    curl
    which
    ldns
    dnsutils
    unixtools.watch
    coreutils
    findutils
    diffutils
    binutils
    gnumake
    gnugrep
    gnused
    gnutar
    gnupg
    gawk
    git
    parallel
    jq
    yq-go
    rclone
    restic
    sshuttle
    socat
    watchman
    m4
    xz
    unrar
    zstd
    gzip
    bat
    ripgrep
    eza
    fd
    httpie
    curlie
    tealdeer
    du-dust
    procs
    dogdns
    gping
    rdfind
  ];
}
