{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    recyclarr = proxied {
      name = "recyclarr";
      proxy = false;
      container = {
        # Pinned: upstream stopped publishing the `latest` tag, so `--pull=always`
        # fails with "manifest unknown" and the container cannot start.
        image = "ghcr.io/recyclarr/recyclarr:8.3.2";
        volumes = [
          "/data/containers/recyclarr/config:/config"
        ];
        extraOptions = [
          "--memory=512M"
        ];
      };
    };
  };
}
