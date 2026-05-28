{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.router.services.syncthing.enable {
    containers.syncthing = {
      autoStart = true;

      macvlans = [ "lan" ];
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
          systemd.network = {
            enable = true;
            networks."10-lan" = {
              matchConfig.Name = "mv-lan";
              linkConfig.RequiredForOnline = "routable";
              address = [ "${config.router.services.syncthing.address}/24" ];
              gateway = [ config.router.lan.address ];
            };
          };

          networking.firewall = {
            allowedTCPPorts = [
              8384
              22000
            ];
            allowedUDPPorts = [
              21027
              22000
            ];
          };

          services.syncthing = {
            enable = true;
            dataDir = "/var/lib/syncthing";
            guiAddress = "0.0.0.0:8384";
            openDefaultPorts = false;

            # Keep peer and folder configuration mutable so trusted clients can be
            # added after reading mako's generated device ID.
            overrideDevices = false;
            overrideFolders = false;

            settings.options = {
              globalAnnounceEnabled = false;
              localAnnounceEnabled = true;
              natEnabled = false;
              relaysEnabled = false;
              urAccepted = -1;
            };
          };
        };
    };
  };
}
