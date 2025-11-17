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
    ./nspawn.nix
    ./performance.nix
    ../../modules/common/base.nix
    ../../modules/common/performance.nix
    ../../modules/common/users.nix
    ../../modules/common/server-tools.nix
    ./network-tuning.nix
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

  zramSwap.enable = true;
  swapDevices = [ ];

  age.secrets.tailscale-key = {
    file = "${secrets}/tailscale-manta.age";
    owner = "root";
    group = "root";
    mode = "400";
  };

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

  ocean = {
    boot = {
      loader = "grub";
      efiCanTouchVariables = false;
      grubDevices = [
        "/dev/sda"
        "/dev/sdb"
        "/dev/sdc"
        "/dev/sdd"
      ];
      grubEfiSupport = false;
    };

    nix = {
      gcSchedule = "12:50";
      gcOptions = "--delete-older-than 15d";
      optimiseSchedule = [ "12:20" ];
    };

    performance.cpuGovernor = "ondemand";
  };

  environment.variables.VDPAU_DRIVER = "va_gl";

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

  # State version
  system.stateVersion = "22.05";
}
