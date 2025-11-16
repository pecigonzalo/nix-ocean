{ proxied, ... }:
{
  virtualisation.oci-containers.containers = {
    portainer = proxied {
      name = "portainer";
      port = 9000;
      container = {
        image = "portainer/portainer";
        volumes = [
          "/var/run/docker.sock:/var/run/docker.sock:ro"
          "/data/containers/portainer:/data"
        ];
        extraOptions = [
          "--memory=128M"
        ];
      };
    };
  };
}
