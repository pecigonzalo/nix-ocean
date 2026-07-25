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
        # the port cleanly, and open 5353 so inbound multicast mDNS answers are
        # not dropped by the container firewall (they are not conntrack-related
        # to the outgoing query).
        services.resolved.enable = false;
        networking.firewall.allowedUDPPorts = [ 5353 ];

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
            # Accept RA routes (needed for the Thread OMR fd7c::/64 route from
            # OTBR) but do not autoconfigure addresses from RAs: this container
            # uses its static fd00::12 as the sole global source. This also
            # guards against any transient extra on-link prefix becoming the
            # preferred (and unroutable) source toward the OMR.
            ipv6AcceptRAConfig.UseAutonomousPrefix = false;
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
            "--log-level=info"
          ];
        };
      };
  };
}
