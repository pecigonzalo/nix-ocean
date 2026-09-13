{ config, pkgs, proxied, ... }:
let
  haproxyConfig = pkgs.writeText "plex-egress.cfg" ''
    global
      log stdout format raw local0
      maxconn 2048

    defaults
      mode tcp
      log global
      option tcplog
      timeout connect 10s
      timeout client 1h
      timeout server 1h

    resolvers plex_dns
      nameserver home 100.101.146.118:53
      resolve_retries 3
      timeout resolve 1s
      timeout retry 1s
      hold valid 10s
      hold nx 30s

    frontend plex_tls
      bind :443
      tcp-request inspect-delay 5s
      tcp-request content accept if { req.ssl_hello_type 1 }
      use_backend plex_tv if { req.ssl_sni -i plex.tv }
      use_backend servers_plex_tv if { req.ssl_sni -i servers.plex.tv }
      use_backend pubsub_plex_tv if { req.ssl_sni -i pubsub.plex.tv }
      use_backend pubsub_pop if { req.ssl_sni -i pubsub06.pop.fra.plex.bz }
      use_backend v4_plex_tv if { req.ssl_sni -i v4.plex.tv }
      use_backend metadata_hosting if { req.ssl_sni -i metadata.prod.hosting.plex.tv }
      default_backend rejected

    backend plex_tv
      server upstream plex.tv:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend servers_plex_tv
      server upstream servers.plex.tv:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend pubsub_plex_tv
      server upstream pubsub.plex.tv:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend pubsub_pop
      server upstream pubsub06.pop.fra.plex.bz:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend v4_plex_tv
      server upstream v4.plex.tv:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend metadata_hosting
      server upstream metadata.prod.hosting.plex.tv:443 resolvers plex_dns resolve-prefer ipv4 init-addr last,libc,none

    backend rejected
      tcp-request content reject
  '';
in
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
      environmentFiles = [
        config.age.secrets.tailscale-proxy.path
      ];
      environment = {
        TS_STATE_DIR = "/var/lib/tailscale";
        TS_SOCKET = "/var/run/tailscale/tailscaled.sock";
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
        "--dns=100.101.146.118"
      ];
    };
    plex-proxy = {
      dependsOn = [ "plex-tunnel" ];
      image = "nixery.dev/haproxy";
      cmd = [
        "haproxy"
        "-db"
        "-f"
        "/etc/haproxy/haproxy.cfg"
      ];
      volumes = [
        "${haproxyConfig}:/etc/haproxy/haproxy.cfg:ro"
      ];
      extraOptions = [
        "--network=container:plex-tunnel"
      ];
    };
    plex = proxied {
      name = "plex";
      port = 32400;
      auth = false;
      container = {
        dependsOn = [ "plex-proxy" ];
        image = "plexinc/pms-docker";
        ports = [
          "32400:32400"
        ];
        environment = {
          PLEX_GID = toString config.users.groups.media.gid;
          PLEX_UID = toString config.users.users.media.uid;
          CHANGE_CONFIG_DIR_OWNERSHIP = "false";
          ADVERTISE_IP = "https://plex.munin.xyz:443";
        };
        environmentFiles = [
          config.age.secrets.plex-claim.path
        ];
        extraOptions = [
          "--device=/dev/dri/renderD128:/dev/dri/renderD128"
          "--device=/dev/dri/card0:/dev/dri/card0"
          "--add-host=plex.tv:172.21.0.150"
          "--add-host=servers.plex.tv:172.21.0.150"
          "--add-host=pubsub.plex.tv:172.21.0.150"
          "--add-host=pubsub06.pop.fra.plex.bz:172.21.0.150"
          "--add-host=v4.plex.tv:172.21.0.150"
          "--add-host=metadata.prod.hosting.plex.tv:172.21.0.150"
          "--label=traefik.http.services.plex.loadbalancer.server.scheme=https"
          "--memory=8G"
          "--tmpfs=/transcode:size=6g,noexec,nodev,nosuid,gid=995,uid=995"
        ];
        volumes = [
          "/data/containers/plex/config:/config"
          "/data/media:/data/media"
        ];
      };
    };
  };
}
