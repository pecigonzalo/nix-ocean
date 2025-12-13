{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager.url = "github:nix-community/home-manager/release-25.05";

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
        # Creave an overlay to use Determinate's nix in nixos-rebuild-ng
        nixos-rebuild-ng-overlay = final: prev: {
          nixos-rebuild-ng = prev.nixos-rebuild-ng.override {
            # Swap the upstream 'nix' with the Determinate one
            nix = determinate.packages.${system}.default // {
              # Manually satisfy the version check
              version = "2.18";
            };
          };
        };
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nixos-rebuild-ng-overlay ];
        };
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
            synth = {
              desc = "Synthesize K8s manifests with cdk8s";
              cmd = "cdk8s synth";
              sources = [ "k8s/**/*" ];
              generates = [ "dist/**/*.yaml" ];
            };
            deploy = {
              desc = "Deploy reef k8s cluster with kapp";
              sources = [ "dist/**/*" ];
              deps = [ "synth" ];
              cmd = "kapp app-group deploy -g cdk8s -d ./dist --yes";
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
        devShells = {
          default = pkgs.mkShellNoCC {
            packages =
              with pkgs;
              [
                bun
                kapp
                vtsls
              ]
              ++ [ taskfilePackage ];
          };
        };
      }
    ));
}
