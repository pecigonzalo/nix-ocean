{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    radarr = proxied {
      name = "radarr";
      port = 7878;
      container = {
        image = "ghcr.io/linuxserver/radarr:6.3.0";
        environment = {
          PUID = toString config.users.users.media.uid;
          PGID = toString config.users.groups.media.gid;
        };
        volumes = [
          "/data/containers/radarr/config:/config"
          "/data/media:/media"
        ];
        extraOptions = [
          "--memory=512M"
        ];
      };
    };
  };
}
