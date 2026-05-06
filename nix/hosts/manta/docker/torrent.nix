{ proxied, config, ... }:
let
  torrentPort = 51850;
  torrentPortString = toString torrentPort;
in
{
  networking.firewall.allowedTCPPorts = [ torrentPort ];
  networking.firewall.allowedUDPPorts = [ torrentPort ];
  virtualisation.oci-containers.containers = {
    qbittorrent = proxied {
      name = "qbit";
      port = 8080;
      host = "qbit";
      container = {
        image = "linuxserver/qbittorrent:latest";
        ports = [
          "${torrentPortString}:${torrentPortString}"
          "${torrentPortString}:${torrentPortString}/udp"
        ];
        environment = {
          PUID = toString config.users.users.media.uid;
          PGID = toString config.users.groups.media.gid;
          DOCKER_MODS = "arafatamim/linuxserver-io-mod-vuetorrent";
          WEBUI_PORT = "8080";
        };
        extraOptions = [
          "--memory=2G"
        ];
        volumes = [
          "/data/containers/qbittorrent/config:/config"
          "/data/media/torrents:/torrents"
          "/data/media/movies:/movies"
          "/data/media:/downloads"
        ];
      };
    };
    qui = proxied {
      name = "qui";
      port = 7476;
      host = "qui";
      container = {
        image = "ghcr.io/autobrr/qui:v1.18";
        environment = {
          QUI__AUTH_DISABLED = "true";
          QUI__I_ACKNOWLEDGE_THIS_IS_A_BAD_IDEA = "true";
           QUI__AUTH_DISABLED_ALLOWED_CIDRS = "10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
        };
        extraOptions = [
          "--memory=1G"
        ];
        volumes = [
          "/data/containers/qui/config:/config"
        ];
      };
    };
  };
}
