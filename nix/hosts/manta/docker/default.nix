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
            "--pull=always"
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
        extraOptions = existingOptions ++ proxyOptions;
        log-driver = "local";
      };
    in
    newContainer;
in
{
  virtualisation.oci-containers.backend = "docker";
  system.userActivationScripts.mkDockerNetworks =
    let
      docker = "${pkgs.docker}/bin/docker";
    in
    ''
      attempts=0
      until ${docker} info >/dev/null 2>&1 || [ $attempts -ge 30 ]; do
        attempts=$((attempts + 1))
        sleep 1
      done

      if ${docker} info >/dev/null 2>&1; then
        ${docker} network inspect proxy >/dev/null 2>&1 || ${docker} network create proxy
        ${docker} network inspect plex >/dev/null 2>&1 || ${docker} network create plex
      else
        echo "warning: docker daemon unavailable, skipped network creation" >&2
      fi
    '';
  _module.args = {
    proxied = proxied;
  };
  imports = [
    ./authelia.nix
    ./traefik.nix
    ./portainer.nix
    ./plex.nix
    ./bazarr.nix
    ./radarr.nix
    ./sonarr.nix
    ./recyclarr.nix
    ./torrent.nix
    ./wordpress.nix
    # ./ghost.nix
  ];
}
