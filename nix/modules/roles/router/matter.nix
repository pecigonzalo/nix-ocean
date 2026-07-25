{
  config,
  pkgs-unstable,
  ...
}:
{
  containers.matter = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;

    # matter.js server (Node) needs roughly twice the RAM of the old Python one.
    memoryLimit = "1G";

    specialArgs = {
      inherit pkgs-unstable;
    };

    config =
      { pkgs-unstable, ... }:
      {
        imports = [
          ../../common/server-tools.nix
          # services.matterjs-server only exists in nixpkgs-unstable; pull the
          # module from there and override the package with the unstable build.
          "${pkgs-unstable.path}/nixos/modules/services/home-automation/matterjs-server.nix"
        ];
        system.stateVersion = "25.05";

        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = [ config.router.services.dns.address ];
        };

        # matter.js runs its own mDNS on UDP 5353; keep resolved off so it owns
        # the port cleanly.
        services.resolved.enable = false;

        systemd.network = {
          enable = true;
          networks."10-lan" = {
            matchConfig.Name = "eth0";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services.matter.address}/24"
              "fd00:1000:1000:1::12/64"
            ];
            gateway = [ config.router.lan.address ];
          };
        };

        services.matterjs-server = {
          enable = config.router.services.matter.enable;
          package = pkgs-unstable.matterjs-server;
          listenAddress = "0.0.0.0";
          port = 5580;
          openFirewall = true;
          extraArgs = [
            "--primary-interface=eth0"
            "--log-level=debug"
          ];
        };
      };
  };
}
