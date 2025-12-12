{
  pkgs,
  ...
}:
{

  systemd.services.init-unifi-network = {
    description = "Create the network bridge for Unifi containers";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network create unifi --interface-name unifi || true
    '';
  };

  virtualisation.oci-containers.containers.unifi-db = {
    image = "mongo:4.4";
    extraOptions = [ "--memory=512M" ];
    networks = [
      "unifi"
    ];
    volumes = [
      "unifi-db:/data/db"
      "${pkgs.writeText "init-mongo.js" ''
        db.getSiblingDB("unifi").createUser({user: "unifi", pwd: "unifi", roles: [{role: "dbOwner", db: "unifi"}]});
        db.getSiblingDB("unifi_stat").createUser({user: "unifi", pwd: "unifi", roles: [{role: "dbOwner", db: "unifi_stat"}]});
      ''}:/docker-entrypoint-initdb.d/init-mongo.js:ro"
    ];
  };

  systemd.services.podman-unifi-db = {
    requires = [ "init-unifi-network.service" ];
    after = [ "init-unifi-network.service" ];
  };

  virtualisation.oci-containers.containers.unifi = {
    image = "ghcr.io/linuxserver/unifi-network-application:10.0.160";
    extraOptions = [ "--memory=1G" ];
    networks = [
      "podman"
      "unifi"
    ];
    environment = {
      MONGO_DBNAME = "unifi";
      MONGO_HOST = "unifi-db";
      MONGO_PORT = "27017";
      MONGO_USER = "unifi";
      MONGO_PASS = "unifi";
    };
    ports = [
      "8443:8443"
      "8080:8080"
      "3478:3478/udp" # STUN port for UniFi devices
      "10001:10001/udp" # Doscovery port for UniFi devices
      # "1900:1900/udp" # SSDP port for UniFi Protect devices
    ];
    volumes = [
      "/etc/unifi:/config"
    ];
    dependsOn = [
      "unifi-db"
    ];
  };
  systemd.services.podman-unifi = {
    requires = [ "init-unifi-network.service" ];
    after = [ "init-unifi-network.service" ];
  };
}
