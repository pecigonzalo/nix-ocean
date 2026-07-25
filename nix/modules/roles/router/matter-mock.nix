# Temporary Matter-over-IP mock device used to bisect commissioning issues.
# Runs home-assistant-matter-hub as a LAN Matter bridge so matter-server can
# commission it on-network, isolating Matter/mDNS from the Thread mesh path.
{ config, ... }:
{
  containers.matter-mock = {
    autoStart = true;

    hostBridge = "br-lan";
    privateNetwork = true;

    memoryLimit = "512M";

    # Home Assistant long-lived token, placed on the host out-of-band (not in
    # git): /var/lib/matter-mock-token.
    bindMounts."/run/matter-mock-token" = {
      hostPath = "/var/lib/matter-mock-token";
      isReadOnly = true;
    };

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

        # Let the bridge's own mDNS responder own UDP 5353.
        services.resolved.enable = false;

        systemd.network = {
          enable = true;
          networks."10-lan" = {
            matchConfig.Name = "eth0";
            linkConfig.RequiredForOnline = "routable";
            address = [
              "${config.router.services."matter-mock".address}/24"
              "fd00:1000:1000:1::13/64"
            ];
            gateway = [ config.router.lan.address ];
          };
        };

        services.home-assistant-matter-hub = {
          enable = config.router.services."matter-mock".enable;
          openFirewall = true;
          accessTokenFile = "/run/matter-mock-token";
          settings = {
            homeAssistantUrl = "http://${config.router.services.home-assistant.address}:8123";
          };
        };
      };
  };
}
