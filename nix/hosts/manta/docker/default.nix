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
      existingOptions = if (container ? extraOptions) then container.extraOptions else [ ];
      proxyOptions =
        if proxy then
          [
            "--network=proxy"
            "--label=traefik.enable=true"
          ]
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
        extraOptions = existingOptions ++ [ "--pull=always" ] ++ proxyOptions;
        log-driver = "local";
      };
    in
    newContainer;
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
        for network in proxy plex immich; do
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
