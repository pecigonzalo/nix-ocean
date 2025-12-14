{
  nixpkgs,
  lib,
  hosts,
  determinate,
  system,
}:
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
      --use-remote-sudo --use-substitutes \
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
        exec ${pkgs.go-task}/bin/task -d ./ --taskfile "$out/share/taskfiles/Taskfile.yml" "$@"
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
