# Immich (photos) on the upstream images.
#
# Tailnet only: the server publishes on loopback and `tailscale serve` fronts it
# with a tailnet certificate. Docker published ports bypass the NixOS firewall,
# so publishing on 0.0.0.0 would put Immich on the internet. Port 443 is already
# bound by Traefik on 0.0.0.0, so serve listens on 8443.
#
# URL: https://manta.<tailnet>.ts.net:8443
#
# No LUKS on purpose: the volume would have to be unlocked at boot, so it would
# sit mounted anyway and add nothing against a compromised host. The isolation
# that matters is here (own network, no host mounts beyond its own data, no
# docker socket, memory caps, no-new-privileges) plus 2FA on the Immich account
# and backups that leave the box.
{
  config,
  pkgs,
  ...
}:
let
  dataDir = "/data/containers/immich";
  httpPort = 2283;
  tailnetPort = 8443;
  # An env file with both keys rather than *_FILE: it contains
  # DB_PASSWORD=... and POSTGRES_PASSWORD=..., the same value twice, so neither
  # image has to interpret a trailing newline.
  dbEnv = config.age.secrets.immich-db-password.path;
  # The images start as root and drop privileges themselves, so cap-drop=ALL
  # needs a test run against the real image before it can be trusted here.
  hardening = [
    "--security-opt=no-new-privileges:true"
  ];
in
{
  # The container images are the source of truth for the app; the release tag
  # floats on purpose since Immich expects to be kept current and migrates its
  # database on start. Downgrades are not supported.
  virtualisation.oci-containers.containers = {
    immich-redis = {
      image = "docker.io/valkey/valkey:9";
      pull = "always";
      networks = [ "immich" ];
      extraOptions = hardening ++ [ "--memory=512M" ];
    };

    immich-db = {
      # Upstream pins this image; it carries the VectorChord/pgvectorscale
      # extensions Immich requires.
      image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
      pull = "always";
      environment = {
        POSTGRES_USER = "immich";
        POSTGRES_DB = "immich";
        POSTGRES_INITDB_ARGS = "--data-checksums";
        # /data is spinning rust, let the image tune Postgres for it.
        DB_STORAGE_TYPE = "HDD";
      };
      environmentFiles = [ dbEnv ];
      volumes = [ "${dataDir}/postgres:/var/lib/postgresql/data" ];
      extraOptions = hardening ++ [
        "--shm-size=128m"
        "--memory=2G"
      ];
      networks = [ "immich" ];
    };

    immich-machine-learning = {
      image = "ghcr.io/immich-app/immich-machine-learning:release";
      pull = "always";
      environment = {
        # Set by upstream compose; keep in sync if it ever changes.
        MACHINE_LEARNING_MODEL_REVISION = "v2";
        # i7-3770 is x86-64-v2 with four cores, so do not fan out.
        MACHINE_LEARNING_WORKERS = "1";
      };
      volumes = [ "/data/containers/immich-cache:/cache" ];
      extraOptions = hardening ++ [ "--memory=6G" ];
      networks = [ "immich" ];
    };

    immich-server = {
      image = "ghcr.io/immich-app/immich-server:release";
      pull = "always";
      dependsOn = [
        "immich-db"
        "immich-redis"
        "immich-machine-learning"
      ];
      environment = {
        DB_HOSTNAME = "immich-db";
        DB_USERNAME = "immich";
        DB_DATABASE_NAME = "immich";
        REDIS_HOSTNAME = "immich-redis";
        IMMICH_MACHINE_LEARNING_URL = "http://immich-machine-learning:3003";
      };
      environmentFiles = [ dbEnv ];
      ports = [ "127.0.0.1:${toString httpPort}:${toString httpPort}" ];
      volumes = [ "${dataDir}/library:/data" ];
      extraOptions = hardening ++ [ "--memory=4G" ];
      networks = [ "immich" ];
    };
  };

  # /data is on the array, make sure it is up before anything writes under it.
  systemd.services.docker-immich-server.unitConfig.RequiresMountsFor = [ dataDir ];
  systemd.services.docker-immich-db.unitConfig.RequiresMountsFor = [ dataDir ];

  # tailscale serve terminates TLS with the tailnet certificate and proxies to
  # the loopback port, so nothing listens on the public interfaces.
  systemd.services.immich-tailnet = {
    description = "Expose Immich on the tailnet with tailscale serve";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${config.services.tailscale.package}/bin/tailscale serve --bg --https=${toString tailnetPort} http://127.0.0.1:${toString httpPort}
    '';
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ tailnetPort ];
}
