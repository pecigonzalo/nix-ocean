{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    recyclarr = proxied {
      name = "recyclarr";
      proxy = false;
      container = {
        # Pinned: upstream stopped publishing tags after 8.3.2, so `latest`
        # no longer resolves and `--pull=always` needs a tag that exists.
        image = "ghcr.io/recyclarr/recyclarr:8.8.0";
        volumes = [
          "/data/containers/recyclarr/config:/config"
        ];
        # Sonarr/Radarr are only on the proxy network; recyclarr needs name
        # resolution to reach them and must not be exposed through Traefik.
        networks = [ "proxy" ];
        extraOptions = [ "--memory=512M" ];
      };
    };
  };
}
