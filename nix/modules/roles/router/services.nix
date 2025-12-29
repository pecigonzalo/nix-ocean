{
  lib,
  config,
  ...
}:
{
  imports = [
    ./unifi.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  virtualisation.oci-containers.containers.matter-server =
    lib.mkIf config.router.services.homeAssistant.enable
      {
        image = "ghcr.io/matter-js/python-matter-server:stable";
        extraOptions = [ "--memory=128m" ];
        networks = [ "host" ];
        volumes = [
          "data:/data"
          "/run/dbus:/run/dbus:ro"
        ];
      };

  virtualisation.oci-containers.containers.home-assistant =
    lib.mkIf config.router.services.homeAssistant.enable
      {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        extraOptions = [ "--memory=1024m" ];
        networks = [ "host" ];
        privileged = true;
        capabilities = {
          NET_RAW = true;
          NET_ADMIN = true;
        };
        devices = lib.optional (
          config.router.services.homeAssistant.zigbeeDevice != null
        ) "${config.router.services.homeAssistant.zigbeeDevice}:/dev/ttyUSB0";
        volumes = [
          "/etc/home-assistant/:/config"
          "/run/dbus:/run/dbus:ro"
        ];
      };
}
