{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    radarr = proxied {
      name = "radarr";
      route.port = 7878;
      container = {
        image = "ghcr.io/linuxserver/radarr:6.4.4.10685-ls323";
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
