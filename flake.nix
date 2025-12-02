{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    flake-utils.url = "github:numtide/flake-utils";
    disko.url = "github:nix-community/disko";
    agenix.url = "github:ryantm/agenix";
    home-manager.url = "github:nix-community/home-manager/release-25.05";

    # Secrets repository (separate git repo)
    secrets = {
      url = "git+ssh://git@github.com/pecigonzalo/nix-ocean-secrets";
      flake = false; # Not a flake, just a directory of files
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      disko,
      agenix,
      home-manager,
      secrets,
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
          ./hosts/${cfg.path}
          # Make agenix module and secrets available to all hosts
          agenix.nixosModules.default
        ];

      # Build a NixOS system configuration
      mkHost =
        name: cfg:
        lib.nixosSystem {
          specialArgs = {
            inherit secrets;
          };
          modules = hostModules name cfg;
        };
    in
    {
      # Generate NixOS configurations for all hosts
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;
    }
    // (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        mkCmd = name: ''
          ${pkgs.nixos-rebuild-ng}/bin/nixos-rebuild-ng \
            --flake .#${name} \
            --target-host root@${name} \
            --build-host root@${name} \
            {{.CLI_ARGS}}
        '';
        taggedHosts = lib.foldl' (
          acc: hostName:
          let
            hostTags = hosts.${hostName}.tags or [ ];
          in
          lib.foldl' (
            innerAcc: tag:
            innerAcc
            // {
              ${tag} = (innerAcc.${tag} or [ ]) ++ [ hostName ];
            }
          ) acc hostTags
        ) { } (lib.attrNames hosts);
        taskfile = {
          version = "3";
          output = "prefixed";
          tasks = {
            default = {
              desc = "Check flake";
              cmd = "nix flake check --no-build";
            };
          }
          # Per tag group tasks
          // lib.mapAttrs' (tag: hostNames: {
            name = "@${tag}";
            value = {
              desc = "Deploy configuration to all ${tag} hosts";
              deps = hostNames;
            };
          }) taggedHosts
          # Per host tasks
          // lib.mapAttrs (name: cfg: {
            desc = "Deploy configuration to ${name}";
            cmds = [
              (mkCmd name)
            ];
          }) hosts;
        };
        yamlFormat = pkgs.formats.yaml { };
        taskfilePackage = pkgs.stdenv.mkDerivation {
          name = "task";
          taskfileYaml = yamlFormat.generate "Taskfile.yml" taskfile;
          dontUnpack = true;
          installPhase = ''
            mkdir -p $out/share/taskfiles $out/bin
            cp "$taskfileYaml" $out/share/taskfiles/Taskfile.yml
            cat > $out/bin/task <<EOF
              #!${pkgs.runtimeShell}
              set -euo pipefail
              exec ${pkgs.go-task}/bin/task -d ./ --taskfile "$out/share/taskfiles/Taskfile.yml" "\$@"
            EOF
            chmod +x $out/bin/task
          '';
        };
        taskfileApp = {
          type = "app";
          program = "${taskfilePackage}/bin/task";
        };
      in
      {
        packages = {
          default = taskfilePackage;
        };
        apps = {
          taskfile = taskfileApp;
        };
      }
    ));
}
