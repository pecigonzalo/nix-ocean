{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Wrap container definitions so every service gets the same defaults and,
  # when `route` is set, the same Traefik wiring.
  #
  # `route = null` runs the container without publishing it. Inside a route:
  #   host     subdomain under `domain` (optional, else the provider default)
  #   rule     full router rule, for what `host` cannot express
  #   port     container port Traefik should target
  #   authelia attach the authelia@docker middleware (default true)
  #   scheme   http or https towards the container
  #   network  docker network Traefik should use, when not `proxy`
  proxied =
    {
      name,
      route ? null,
      container,
    }:
    let
      routeRule =
        route.rule or (
          if (route.host or null) != null then
            "Host(`${route.host}.${route.domain or "munin.xyz"}`)"
          else
            null
        );
      routeLabels = {
        "traefik.enable" = "true";
      }
      // lib.optionalAttrs (routeRule != null) {
        "traefik.http.routers.${name}.rule" = routeRule;
      }
      // lib.optionalAttrs (route.authelia or true) {
        "traefik.http.routers.${name}.middlewares" = "authelia@docker";
      }
      // lib.optionalAttrs ((route.port or null) != null) {
        "traefik.http.services.${name}.loadbalancer.server.port" = toString route.port;
      }
      // lib.optionalAttrs ((route.scheme or null) != null) {
        "traefik.http.services.${name}.loadbalancer.server.scheme" = route.scheme;
      }
      // lib.optionalAttrs ((route.network or null) != null) {
        "traefik.docker.network" = route.network;
      };
    in
    container
    // {
      # Pull on every start. Without this a restart reuses the local image
      # forever, which is how WordPress ended up on a vulnerable PHP release
      # (CVE-2026-109618).
      pull = container.pull or "always";
      log-driver = container.log-driver or "local";
    }
    // lib.optionalAttrs (route != null) {
      networks = lib.unique ((container.networks or [ ]) ++ [ (route.network or "proxy") ]);
      labels = (container.labels or { }) // routeLabels;
    };

  dockerNetworks = lib.unique (
    lib.concatMap (container: container.networks or [ ]) (
      lib.attrValues config.virtualisation.oci-containers.containers
    )
  );
in
{
  virtualisation.oci-containers.backend = "docker";

  # Containers reference these networks by name, so they have to exist before
  # the first `docker run`. This used to live in a user activation script,
  # which raced with the container units on activation and on boot.
  systemd.services = {
    docker-networks = {
      description = "Create the docker networks used by the oci containers";
      wantedBy = [ "multi-user.target" ];
      requires = [ "docker.service" ];
      after = [ "docker.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        # Derived from the container definitions, so no module has to remember
        # to add its network here.
        for network in ${lib.escapeShellArgs dockerNetworks}; do
          ${pkgs.docker}/bin/docker network inspect "$network" >/dev/null 2>&1 \
            || ${pkgs.docker}/bin/docker network create "$network"
        done
      '';
    };
  }
  // lib.mapAttrs' (name: _: {
    name = "docker-${name}";
    value = {
      wants = [ "docker-networks.service" ];
      after = [ "docker-networks.service" ];
    };
  }) config.virtualisation.oci-containers.containers;
  _module.args = {
    proxied = proxied;
  };
  imports = [
    ./authelia.nix
    ./traefik.nix
    ./plex.nix
    ./immich.nix
    ./socket-proxy.nix
    ./bazarr.nix
    ./radarr.nix
    ./sonarr.nix
    ./recyclarr.nix
    ./torrent.nix
    ./trek.nix
    ./wordpress.nix
    # ./ghost.nix
    ./wealthfolio.nix
  ];
}
