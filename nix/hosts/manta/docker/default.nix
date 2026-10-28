{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Wrap container definitions to simplify instantiation
  proxied =
    {
      name,
      proxy ? true,
      auth ? true,
      host ? null,
      port ? null,
      domain ? "munin.xyz",
      container,
    }:
    let
      existingOptions = container.extraOptions or [ ];
      # The container's own networks win; proxied containers default to proxy.
      containerNetworks = container.networks or (lib.optional proxy "proxy");
      proxyOptions =
        if proxy then
          [ "--label=traefik.enable=true" ]
          # Point the provider at the right network when it is not the default
          # one, so a container can live off the shared proxy network.
          ++ lib.optional (!(builtins.elem "proxy" containerNetworks))
            "--label=traefik.docker.network=${builtins.head containerNetworks}"
          ++ lib.optional auth "--label=traefik.http.routers.${name}.middlewares=authelia@docker"
          ++ lib.optional (
            port != null
          ) "--label=traefik.http.services.${name}.loadbalancer.server.port=${toString port}"
          ++ lib.optional (host != null) "--label=traefik.http.routers.${name}.rule=Host(`${host}.${domain}`)"
        else
          [ ];
      newContainer = container // {
        # Pull on every start, independent of whether the container is proxied.
        # Without this a restart reuses the local image forever, which is how
        # WordPress ended up on a vulnerable PHP release (CVE-2026-109618).
        extraOptions = existingOptions ++ proxyOptions;
        networks = lib.unique containerNetworks;
        pull = container.pull or "always";
        log-driver = "local";
      };
    in
    newContainer;

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
