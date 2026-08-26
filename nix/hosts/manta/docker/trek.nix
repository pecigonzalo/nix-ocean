{ proxied, ... }:
{
  virtualisation.oci-containers.containers = {
    trek = proxied {
      name = "trek";
      port = 3000;
      container = {
        image = "mauriceboe/trek:latest";
        environment = {
          NODE_ENV = "production";
          PORT = "3000";
          APP_URL = "https://trek.munin.xyz";
          ALLOWED_ORIGINS = "https://trek.munin.xyz";
          FORCE_HTTPS = "true";
          TRUST_PROXY = "1";
        };
        volumes = [
          "/data/containers/trek/data:/app/data"
          "/data/containers/trek/uploads:/app/uploads"
        ];
        extraOptions = [
          "--read-only"
          "--security-opt=no-new-privileges:true"
          "--cap-drop=ALL"
          "--cap-add=CHOWN"
          "--cap-add=SETUID"
          "--cap-add=SETGID"
          "--tmpfs=/tmp:noexec,nosuid,size=128m"
          "--memory=512M"
        ];
      };
    };
  };
}
