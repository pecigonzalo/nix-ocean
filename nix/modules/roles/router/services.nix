{
  lib,
  pkgs,
  config,
  ...
}:
{
  virtualisation.podman =
    lib.mkIf (config.router.services.pihole.enable || config.router.services.homeAssistant.enable)
      {
        enable = true;
        dockerCompat = true;
      };

  # Firewall rules for router services
  # Note: lan and tailscale0 are already in trustedInterfaces (networking.nix)
  # so these rules are redundant but kept for explicitness
  networking.firewall.interfaces.lan.allowedTCPPorts =
    (lib.optionals config.router.services.pihole.enable [ 80 ])
    ++ (lib.optionals config.router.services.homeAssistant.enable [ 8123 ]);

  networking.firewall.interfaces.lan.allowedUDPPorts =
    lib.optionals config.router.services.pihole.enable
      [
        53
        67
        68
      ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts =
    (lib.optionals config.router.services.pihole.enable [ 80 ])
    ++ (lib.optionals config.router.services.homeAssistant.enable [ 8123 ]);

  networking.firewall.interfaces.tailscale0.allowedUDPPorts =
    lib.optionals config.router.services.pihole.enable
      [
        53
        67
        68
      ];

  virtualisation.oci-containers.containers.pihole = lib.mkIf config.router.services.pihole.enable {
    image = "pihole/pihole:latest";
    extraOptions = [
      "--memory=256m"
      "--dns=1.1.1.1"
    ];
    networks = [ "host" ];
    privileged = true;
    environmentFiles = [
      config.router.services.pihole.secretsFile
    ];
    environment = {
      FTLCONF_misc_etc_dnsmasq_d = "true";
      FTLCONF_dns_upstreams = config.router.services.pihole.upstreams;
      FTLCONF_dns_blocking_mode = "NODATA";
      FTLCONF_dns_interface = "lan";
      FTLCONF_dns_bogusPriv = "true";
      FTLCONF_dns_domainNeeded = "true";
      FTLCONF_dns_expandHosts = "true";
      FTLCONF_dns_hosts = lib.concatStringsSep ";" config.router.services.pihole.dnsHosts;
      FTLCONF_dhcp_active = "true";
      FTLCONF_dhcp_ipv6 = "true";
      FTLCONF_dhcp_rapidCommit = "true";
      FTLCONF_dhcp_start = config.router.services.pihole.dhcpRange.start;
      FTLCONF_dhcp_end = config.router.services.pihole.dhcpRange.end;
      FTLCONF_dhcp_router = config.router.lan.address;
      FTLCONF_dhcp_hosts = lib.concatStringsSep ";" config.router.services.pihole.dhcpHosts;
    };
    volumes = [
      "/etc/pihole:/etc/pihole"
      # Mount the custom config to force specific interface binding
      "${pkgs.writeText "99-interfaces.conf" ''
        interface=lo
        interface=tailscale0
        interface=lan
        bind-interfaces
      ''}:/etc/dnsmasq.d/99-interfaces.conf"
    ];
  };

  systemd.services.init-unifi-network = {
    description = "Create the network bridge for Unifi containers";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.podman}/bin/podman network create unifi
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

  virtualisation.oci-containers.containers.matter-server =
    lib.mkIf config.router.services.homeAssistant.enable
      {
        image = "ghcr.io/matter-js/python-matter-server:stable";
        extraOptions = [ "--memory=128m" ];
        networks = [ "host" ];
        volumes = [
          "data:/data"
          "/run/dbus:/run/dbus:ro"
        ];
      };

  virtualisation.oci-containers.containers.home-assistant =
    lib.mkIf config.router.services.homeAssistant.enable
      {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        extraOptions = [ "--memory=1024m" ];
        networks = [ "host" ];
        privileged = true;
        capabilities = {
          NET_RAW = true;
          NET_ADMIN = true;
        };
        devices = lib.optional (
          config.router.services.homeAssistant.zigbeeDevice != null
        ) "${config.router.services.homeAssistant.zigbeeDevice}:/dev/ttyUSB0";
        volumes = [
          "/etc/home-assistant/:/config"
          "/run/dbus:/run/dbus:ro"
        ];
      };
}
