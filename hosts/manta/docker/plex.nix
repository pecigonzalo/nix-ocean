{ config, proxied, ... }:
{
  networking.firewall.allowedTCPPorts = [ 32400 ];
  virtualisation.oci-containers.containers = {
    # jelly = proxied {
    #   name = "jelly";
    #   port = 8096;
    #   auth = false;
    #   container = {
    #     image = "jellyfin/jellyfin";
    #     user = "995:995";
    #     ports = [ "8096:8096" ];
    #     environment = {
    #       JELLYFIN_FFmpeg__analyzeduration = "20000000000";
    #       JELLYFIN_FFmpeg__probesize = "500000000";
    #     };
    #     volumes = [
    #       "/data/containers/jellyfin/config:/config"
    #       "/data/containers/jellyfin/cache:/cache"
    #       "/data/media:/data/media"
    #     ];
    #     extraOptions = [
    #       "--group-add=303"
    #       "--group-add=26"
    #       "--device=/dev/dri/renderD128:/dev/dri/renderD128"
    #       "--device=/dev/dri/card0:/dev/dri/card0"
    #     ];
    #   };
    # };
    plex-tunnel = {
      image = "ghcr.io/tailscale/tailscale:latest";
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SOCKET = "/var/run/tailscale/tailscaled.sock";
        TS_AUTHKEY = "tskey-auth-khwrSD37p321CNTRL-7w7YSm8HM34yHyHTszjA94Xzsz3rmf1W1";
        TS_EXTRA_ARGS = "--exit-node=100.112.15.102 --accept-routes --accept-dns --exit-node-allow-lan-access";
        TS_HOSTNAME = "plex-proxy";
        TS_AUTH_ONCE = "true";
        TS_USERSPACE = "false";
      };
      volumes = [ "/data/containers/tailscale/var/lib/tailscale:/var/lib/tailscale" ];
      extraOptions = [
        "--ip=172.21.0.150"
        "--network=proxy"
        "--cap-add=NET_ADMIN"
        "--dns=100.112.15.102"
      ];
    };
    plex-proxy = {
      dependsOn = [ "plex-tunnel" ];
      image = "nixery.dev/socat/netcat-gnu/curl";
      cmd = [
        "socat"
        "-dd"
        "TCP-LISTEN:443,fork,reuseaddr"
        "TCP:plex.tv:443"
      ];
      extraOptions = [
        "--network=container:plex-tunnel"
      ];
    };
    plex = proxied {
      name = "plex";
      port = 32400;
      container = {
        dependsOn = [ "plex-proxy" ];
        image = "plexinc/pms-docker";
        ports = [
          "32400:32400"
        ];
        environment = {
          PLEX_GID = toString config.users.groups.media.gid;
          PLEX_UID = toString config.users.users.media.uid;
          PLEX_CLAIM = "claim-kVPC3fbsj75x1Vr2xCAL";
          CHANGE_CONFIG_DIR_OWNERSHIP = "false";
          ADVERTISE_IP = "https://plex.munin.xyz";
        };
        extraOptions = [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
          "--device=/dev/dri/card0:/dev/dri/card0"
          "--add-host=plex.tv:172.21.0.150"
          "--memory=8G"
        ];
        volumes = [
          "/data/containers/plex/config:/config"
          "/data/media:/data/media"
          "/dev/shm:/transcode"
        ];
      };
    };
  };
}
