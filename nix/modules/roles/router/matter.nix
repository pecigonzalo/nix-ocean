{ config, ... }:
{
  containers.matter = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;

    memoryLimit = "512M";

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

        # matter-server ships its own (CHIP minimal) mDNS stack, which must own
        # UDP 5353 for commissioning discovery. Disable resolved so it does not
        # also bind the mDNS port and starve CHIP's discovery. OTBR's avahi runs
        # in a separate container and reaches this one over the br-lan bridge.
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

        services.matter-server = {
          enable = config.router.services.matter.enable;
          openFirewall = true;
          logLevel = "debug";
          extraArgs = {
            "primary-interface" = "eth0";
            "log-level-sdk" = "detail";
          };
        };
      };
  };
}
