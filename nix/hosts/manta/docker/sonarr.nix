{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    sonarr = proxied {
      name = "sonarr";
      port = 8989;
      container = {
        image = "ghcr.io/linuxserver/sonarr:4.0.20.3014-ls329";
        environment = {
          PUID = toString config.users.users.media.uid;
          PGID = toString config.users.groups.media.gid;
        };
        volumes = [
          "/data/containers/sonarr/config:/config"
          "/data/media:/media"
        ];
        extraOptions = [
          "--memory=512M"
        ];
      };
    };
  };
}
