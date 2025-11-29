{ pkgs, proxied, ... }:
{
  networking.firewall.allowedTCPPorts = [
    8443
    8080
  ];
  networking.firewall.allowedUDPPorts = [ 3478 ];
  virtualisation.oci-containers.containers = {
    unifi-db =
      let
        mongoInit = pkgs.writeText "init-mongo.js" ''
          db.getSiblingDB("unifi").createUser({user: "unifi", pwd: "unifi", roles: [{role: "dbOwner", db: "unifi"}]});
          db.getSiblingDB("unifi_stat").createUser({user: "unifi", pwd: "unifi", roles: [{role: "dbOwner", db: "unifi_stat"}]});
        '';
      in
      {
        image = "mongo:4.4";
        volumes = [
          "/data/containers/unifi-db:/data/db"
          "${mongoInit}:/docker-entrypoint-initdb.d/init-mongo.js:ro"
        ];
        extraOptions = [
          "--network=proxy"
          "--memory=512M"
        ];
        log-driver = "local";
      };
    unifi = proxied {
      name = "unifi";
      port = 8443;
      host = "control";
      container = {
        image = "ghcr.io/linuxserver/unifi-network-application:10.0.160";
        environment = {
          PUID = "1000";
          PGID = "1000";
          TZ = "Etc/UTC";
          MONGO_DBNAME = "unifi";
          MONGO_HOST = "unifi-db";
          MONGO_PORT = "27017";
          MONGO_USER = "unifi";
          MONGO_PASS = "unifi";
        };
        ports = [
          "8443:8443"
          "8080:8080"
          "3478:3478/udp"
        ];
        extraOptions = [
          "--label=traefik.http.services.unifi.loadbalancer.server.scheme=https"
          "--memory=1G"
        ];
        volumes = [
          "/data/containers/unifi:/config"
        ];
        dependsOn = [
          "unifi-db"
        ];
      };
    };
  };
}
