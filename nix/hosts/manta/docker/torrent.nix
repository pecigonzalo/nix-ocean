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
  };
}
