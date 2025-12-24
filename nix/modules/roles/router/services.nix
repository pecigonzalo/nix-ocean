{
  lib,
  pkgs,
  config,
  ...
}:
let
  dhcpRange = {
    start = "192.168.127.100";
    end = "192.168.127.200";
  };
  dhcpHosts = [
    "EC:71:DB:D3:53:99,192.168.127.50,reolink"
    "78:8A:20:D9:69:1F,192.168.127.22,ap-upstairs"
    "24:5A:4C:11:C5:1C,192.168.127.21,ap-main"
    "9C:05:D6:F4:E3:3E,192.168.127.20,switch"
    "4c:77:cb:e9:a9:76,192.168.127.30,beta-wlan"
    "4c:44:5b:89:2e:b1,192.168.127.31,guppy-wlan"
    "7c:50:79:23:d8:68,192.168.127.32,tetra-wlan"
  ];
  dnsHosts = [
    "192.168.127.10 beta"
    "192.168.127.11 guppy"
    "192.168.127.12 tetra"
  ];
in
{
  imports = [
    ./unifi.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };
  # virtualisation.oci-containers.containers.pihole = {
  #   image = "pihole/pihole:latest";
  #   extraOptions = [
  #     "--memory=256m"
  #     "--dns=1.1.1.1"
  #   ];
  #   networks = [ "host" ];
  #   privileged = true;
  #   environmentFiles = [
  #     config.age.secrets.pihole.path
  #   ];
  #   environment = {
  #     FTLCONF_misc_etc_dnsmasq_d = "true";
  #     FTLCONF_dns_upstreams = "1.1.1.1;8.8.8.8";
  #     FTLCONF_dns_blocking_mode = "NODATA";
  #     FTLCONF_dns_interface = "mv-lan-bridge";
  #     FTLCONF_dns_listeningMode = "BIND";
  #     FTLCONF_dns_bogusPriv = "true";
  #     FTLCONF_dns_domainNeeded = "true";
  #     FTLCONF_dns_expandHosts = "true";
  #     FTLCONF_dns_hosts = lib.concatStringsSep ";" dnsHosts;
  #     FTLCONF_dhcp_active = "false";
  #     FTLCONF_dhcp_ipv6 = "false";
  #     FTLCONF_dhcp_rapidCommit = "true";
  #     FTLCONF_dhcp_start = dhcpRange.start;
  #     FTLCONF_dhcp_end = dhcpRange.end;
  #     FTLCONF_dhcp_router = config.router.lan.address;
  #     FTLCONF_dhcp_hosts = lib.concatStringsSep ";" dhcpHosts;
  #   };
  #   volumes = [
  #     "/etc/pihole:/etc/pihole"
  #     # Mount the custom config to force specific interface binding
  #     "${pkgs.writeText "99-interfaces.conf" ''
  #       interface=lo
  #       interface=tailscale0
  #       interface=mv-lan-bridge
  #       bind-interfaces
  #     ''}:/etc/dnsmasq.d/99-interfaces.conf"
  #   ];
  # };
  # systemd.services.podman-pihole = {
  #   requires = [ "tailscaled.service" ];
  #   after = [ "tailscaled.service" ];
  # };
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
