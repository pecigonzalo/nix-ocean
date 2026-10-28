{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Logs use the NixOS default driver, journald, so every container's output lands
  # in the journal (bounded and rate limited by systemd) and reaches Grafana Cloud
  # through Alloy's loki.source.journal. `docker logs` still reads it back.
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
    }
    // lib.optionalAttrs (route != null) {
      networks = lib.unique ((container.networks or [ ]) ++ [ (route.network or "proxy") ]);
      labels = (container.labels or { }) // routeLabels;
    };

  docker = "${pkgs.docker}/bin/docker";

  dockerNetworks = lib.unique (
    lib.concatMap (container: container.networks or [ ]) (
      lib.attrValues config.virtualisation.oci-containers.containers
    )
  );

  # proxy is pinned to a fixed subnet because plex-tunnel uses a static IP on
  # it, and the default IPAM pool depends on the order networks were created.
  proxyNetwork = lib.optionalString (lib.elem "proxy" dockerNetworks) ''
    ${docker} network inspect proxy >/dev/null 2>&1 \
      || ${docker} network create --label=ocean.managed=true --subnet=172.21.0.0/16 proxy
  '';
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
        declared="${lib.concatStringsSep " " dockerNetworks}"

        ${proxyNetwork}

        for network in ${lib.escapeShellArgs (lib.remove "proxy" dockerNetworks)}; do
          ${docker} network inspect "$network" >/dev/null 2>&1 \
            || ${docker} network create --label=ocean.managed=true "$network"
        done

        # Drop networks this service created that are no longer declared. Only
        # labelled ones, so networks made by hand are never touched, and the
        # removal is allowed to fail because a container can still hold one
        # while it is being restarted.
        for network in $(${docker} network ls \
            --filter label=ocean.managed=true --format '{{.Name}}'); do
          case " $declared " in
            *" $network "*) ;;
            *) ${docker} network rm "$network" >/dev/null 2>&1 || true ;;
          esac
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
