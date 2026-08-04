{
  config,
  lib,
  pkgs,
  ...
}:
{
  containers.thread = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;
    enableTun = true;

    memoryLimit = "256M";

    # Mount Thread USB radio device and the TUN device otbr-agent uses to
    # create the wpan0 Thread network interface.
    bindMounts = {
      "/dev/thread" = {
        hostPath = config.router.services.thread.device;
        isReadOnly = false;
      };
      "/dev/net/tun" = {
        hostPath = "/dev/net/tun";
        isReadOnly = false;
      };
    };
    allowedDevices = [
      {
        node = "/dev/ttyACM0";
        modifier = "rwm";
      }
      {
        node = "/dev/net/tun";
        modifier = "rwm";
      }
    ];

    config =
      { ... }:
      {
        imports = [ ../../common/server-tools.nix ];
        system.stateVersion = "25.05";

        networking = {
          useDHCP = false;
          useNetworkd = true;
          useHostResolvConf = false;
          nameservers = [ config.router.services.dns.address ];
        };

        systemd.network = {
          enable = true;
          networks."10-lan" = {
            matchConfig.Name = "eth0";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services.thread.address}/24"
            ]
            ++ lib.optional (
              config.router.services.thread.address6 != null
            ) "${config.router.services.thread.address6}/${toString config.router.lan.prefixLength6}";
            gateway = [ config.router.lan.address ];
          };
        };

        # Avahi must be the sole mDNS listener in this container. OTBR uses
        # it for the MeshCoP border-router advertisement; systemd-resolved's
        # competing 5353 socket makes that advertisement unreliable.
        services.resolved.enable = false;

        services.avahi = {
          enable = true;
          openFirewall = true;
          ipv4 = true;
          ipv6 = true;
          allowInterfaces = [ "eth0" ];
        };

        services.openthread-border-router = {
          enable = true;

          openFirewall = true;
          backboneInterfaces = [ "eth0" ];

          # otbr-agent's REST API defaults to 127.0.0.1, which is unreachable
          # from the separate matter/home-assistant containers. Listen on all
          # addresses so they can reach it over the LAN.
          rest.listenAddress = "::";

          radio = {
            device = "/dev/thread";
            baudRate = 460800;
            flowControl = true;
          };
        };

        # The EFR32 RCP boots at 0 dBm. Reapply the adapter's supported
        # maximum whenever OTBR starts; this changes only RF output power and
        # does not alter the Thread dataset or network identity.
        systemd.services.otbr-agent.serviceConfig.ExecStartPost = pkgs.writeScript "set-thread-tx-power" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          for attempt in {1..30}; do
            if ${pkgs.openthread-border-router}/bin/ot-ctl txpower 20; then
              exit 0
            fi
            ${pkgs.coreutils}/bin/sleep 1
          done

          echo "Unable to set Thread radio TX power" >&2
          exit 0
        '';
      };
  };
}
