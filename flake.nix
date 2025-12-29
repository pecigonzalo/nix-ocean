{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko.url = "github:nix-community/disko";
    flake-utils.url = "github:numtide/flake-utils";
    agenix.url = "github:ryantm/agenix";

    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";

    # Secrets repository (separate git repo)
    secrets = {
      url = "git+ssh://git@github.com/pecigonzalo/nix-ocean-secrets";
      flake = false; # Not a flake, just a directory of files
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      flake-utils,
      disko,
      agenix,
      home-manager,
      secrets,
      determinate,
      ...
    }:
    let
      lib = nixpkgs.lib;

      # Host definitions - single source of truth
      hosts = {
        # Router
        mako = {
          path = "mako";
          modules = [ disko.nixosModules.disko ];
          tags = [ "router" ];
        };

        # Cloud
        manta = {
          path = "manta";
          modules = [ home-manager.nixosModules.home-manager ];
          tags = [ "cloud" ];
        };

        # Reef cluster nodes
        beta = {
          path = "reef/beta";
          modules = [ disko.nixosModules.disko ];
          tags = [ "reef" ];
        };
        guppy = {
          path = "reef/guppy";
          modules = [ disko.nixosModules.disko ];
          tags = [ "reef" ];
        };
        tetra = {
          path = "reef/tetra";
          modules = [ disko.nixosModules.disko ];
          tags = [ "reef" ];
        };

      };

      # Common modules for a host (used by both NixOS and Colmena)
      hostModules =
        name: cfg:
        (cfg.modules or [ ])
        ++ [
          ./nix/hosts/${cfg.path}
          # Make agenix module and secrets available to all hosts
          agenix.nixosModules.default
        ];

      # Build a NixOS system configuration
      mkHost =
        name: cfg:
        lib.nixosSystem {
          specialArgs = {
            inherit nixpkgs-unstable;
            inherit agenix;
            inherit secrets;
          };
          modules = hostModules name cfg;
        };

      tasks = import ./nix/lib/tasks.nix;
    in
    {
      # Generate NixOS configurations for all hosts
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        tasksForSystem = tasks {
          inherit
            nixpkgs
            lib
            hosts
            determinate
            system
            ;
        };
      in
      {
        packages = tasksForSystem.packages;
        apps = tasksForSystem.apps;
        devShells = {
          default = pkgs.mkShellNoCC {
            packages =
              with pkgs;
              [
                bun
                kapp
                vtsls
              ]
              ++ [ tasksForSystem.packages.default ];
          };
        };
      }
    ));
}
