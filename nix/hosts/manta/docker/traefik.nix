{ pkgs, ... }:
let
  yamlFormat = pkgs.formats.yaml { };
  staticRoutes = yamlFormat.generate "staticRoutes.yaml" {
    http = {
      routers.ha = {
        entryPoints = [
          "web"
          "websecure"
        ];
        middlewares = [ "authelia@docker" ];
        service = "ha";
        rule = "Host(`ha.munin.xyz`)";
      };
      services.ha.loadBalancer.servers = [
        { url = "http://100.112.15.102:8123"; }
      ];
    };
  };
in
{
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
  virtualisation.oci-containers.containers = {
    traefik = {
      image = "traefik:v2.8";
      ports = [
        "80:80"
        "443:443"
      ];
      extraOptions = [
        "--pull=always"
        "--network=proxy"
        "--label=traefik.enable=true"
        "--label=traefik.http.routers.api.service=api@internal"
        "--label=traefik.http.routers.api.middlewares=authelia@docker"
        "--memory=256M"
      ];
      cmd = [
        "--log=true"
        "--accesslog=true"
        "--log.level=INFO"
        "--api=true"
        "--api.dashboard=true"
        "--pilot.dashboard=false"
        "--global.sendAnonymousUsage=false"
        "--global.checkNewVersion=false"
        "--providers.docker=true"
        "--providers.docker.network=proxy"
        "--providers.docker.exposedByDefault=false"
        "--providers.docker.defaultRule=Host(`{{ normalize .Name }}.munin.xyz`)"
        "--providers.file.filename=/config/routes.static.yaml"
        "--entrypoints.websecure.address=:443/tcp"
        "--entrypoints.websecure.http.tls.certResolver=letsencrypt"
        "--entrypoints.web.address=:80/tcp"
        "--entrypoints.web.http.redirections.entryPoint.to=websecure"
        "--entrypoints.web.http.redirections.entryPoint.scheme=https"
        "--entrypoints.web.http.redirections.entrypoint.permanent=true"
        "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
        #  "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
        "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
        "--certificatesresolvers.letsencrypt.acme.email=weedv2@gmail.com"
        "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
        "--serversTransport.insecureSkipVerify=true"
      ];
      volumes = [
        "/var/run/docker.sock:/var/run/docker.sock:ro"
        "/data/containers/traefik/letsencrypt:/letsencrypt"
        "/data/containers/traefik/config:/config"
        "${staticRoutes}:/config/routes.static.yaml"
      ];
      log-driver = "local";
    };
  };
}
