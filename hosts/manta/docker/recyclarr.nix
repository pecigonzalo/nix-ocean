{ proxied, config, ... }:
{
  virtualisation.oci-containers.containers = {
    recyclarr = proxied {
      name = "recyclarr";
      container = {
        image = "ghcr.io/recyclarr/recyclarr:latest";
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
