{ lib, ... }:
{
  nix = {
    settings = {
      # Optimize store automatically during rebuilds
      auto-optimise-store = true;

      # Enable flakes and new nix command
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      # Build in sandbox for reproducibility
      sandbox = true;

      # Allow substitutes from cache
      substituters = [
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];

      # Optimize builds
      cores = 0; # Use all available cores
      max-jobs = "auto";

      # Keep build logs
      keep-build-log = true;
      log-lines = 20;

      # Warn about dirty Git trees
      warn-dirty = true;
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
      # Run GC with low priority to avoid impacting system performance
      randomizedDelaySec = "45min";
    };

    # Optimize store weekly (deduplicate files)
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # Allow unfree packages (useful for firmware, drivers)
  nixpkgs.config.allowUnfree = true;

  # Use the latest Linux kernel LTS
  # boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest; # Commented out - keep stable by default
}
