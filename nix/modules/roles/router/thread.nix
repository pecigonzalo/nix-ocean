{ config, ... }:
{
  containers.thread = {
    autoStart = true;

    macvlans = [ "lan" ];
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
            matchConfig.Name = "mv-lan";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services.thread.address}/24"
              "fd00:1000:1000:1::11/64"
            ];
            gateway = [ config.router.lan.address ];
          };
        };

        services.avahi = {
          enable = true;
          openFirewall = true;
          ipv4 = true;
          ipv6 = true;
          allowInterfaces = [ "mv-lan" ];
        };

        services.openthread-border-router = {
          enable = true;

          openFirewall = true;
          backboneInterfaces = [ "mv-lan" ];

          # otbr-agent's REST API defaults to 127.0.0.1, which is unreachable
          # now that OTBR lives in its own container, separate from Home
          # Assistant. Listen on all addresses so HA can reach it over the LAN.
          rest.listenAddress = "::";

          radio = {
            device = "/dev/thread";
            baudRate = 460800;
            flowControl = true;
          };
        };
      };
  };
}
