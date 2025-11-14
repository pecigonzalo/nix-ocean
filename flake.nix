{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    
    # Secrets repository (separate git repo)
    secrets = {
      url = "git+ssh://git@github.com/pecigonzalo/nix-ocean-secrets";
      flake = false; # Not a flake, just a directory of files
    };
  };

  outputs =
    {
      nixpkgs,
      disko,
      agenix,
      secrets,
      ...
    }:
    let
      # Host definitions - single source of truth
      hosts = {
        # Router
        mako = {
          path = "mako";
          system = "x86_64-linux";
          modules = [ disko.nixosModules.disko ];
        };

        # Cloud
        manta = {
          path = "manta";
          system = "x86_64-linux";
        };

        # Reef cluster nodes
        beta = {
          path = "reef/beta";
          system = "x86_64-linux";
          modules = [ disko.nixosModules.disko ];
        };
        guppy = {
          path = "reef/guppy";
          system = "x86_64-linux";
          modules = [ disko.nixosModules.disko ];
        };
        tetra = {
          path = "reef/tetra";
          system = "x86_64-linux";
          modules = [ disko.nixosModules.disko ];
        };

      };

      # Build a NixOS system configuration
      mkHost =
        name: config:
        nixpkgs.lib.nixosSystem {
          system = config.system;
          modules = (config.modules or [ ]) ++ [
            ./hosts/${config.path}
            # Make agenix module and secrets available to all hosts
            agenix.nixosModules.default
            { _module.args = { inherit secrets; }; }
          ];
        };

      # Create deploy/build apps for a host
      mkApps =
        system: name:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          "deploy-${name}" = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "deploy-${name}" ''
                exec ${pkgs.nixos-rebuild-ng}/bin/nixos-rebuild-ng switch \
                  --flake ".#${name}" \
                  --target-host "root@${name}" \
                  --build-host "root@${name}"
              ''
            );
          };
          "build-${name}" = {
            type = "app";
            program = toString (
              pkgs.writeShellScript "build-${name}" ''
                exec ${pkgs.nixos-rebuild-ng}/bin/nixos-rebuild-ng build \
                  --flake ".#${name}" \
                  --target-host "root@${name}" \
                  --build-host "root@${name}"
              ''
            );
          };
        };
    in
    {
      # Generate NixOS configurations for all hosts
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      # Generate deployment apps for common systems
      apps =
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ]
          (system: nixpkgs.lib.foldl' (acc: name: acc // mkApps system name) { } (builtins.attrNames hosts));
    };
}
