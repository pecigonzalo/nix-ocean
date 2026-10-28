{ config, proxied, ... }:
{
  virtualisation.oci-containers.containers = {
    bazarr = proxied {
      name = "bazarr";
      # No host: published as bazarr.munin.xyz by the provider default rule.
      route = { };
      container = {
        image = "linuxserver/bazarr:latest";
        environment = {
          PUID = toString config.users.users.media.uid;
          PGID = toString config.users.groups.media.gid;
        };
        volumes = [
          "/data/containers/bazarr/config:/config"
          "/data/media:/media"
        ];
        extraOptions = [
          "--memory=256M"
        ];
      };
    };
  };
}
