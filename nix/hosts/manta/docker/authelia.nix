{
  config,
  pkgs,
  proxied,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  autheliaUsers = config.age.secrets.authelia-users.path;
  autheliaJwtSecret = config.age.secrets.authelia-jwt-secret.path;
  autheliaStorageKey = config.age.secrets.authelia-storage-key.path;

  autheliaConfig = yamlFormat.generate "configuration.yml" {
    server = {
      address = "tcp://0.0.0.0:9091/";
    };
    log = {
      level = "info";
    };

    totp = {
      issuer = "auth.julesinabox.com";
      period = "30";
      skew = "1";
    };

    webauthn = {
      enable_passkey_login = true;
    };

    authentication_backend = {
      file = {
        path = "/config/users.yml";
      };
    };

    access_control = {
      default_policy = "one_factor";
      rules = [
        {
          domain = [ "bazarr.julesinabox.com" ];
          resources = [
            "^/api(/.*)?$"
          ];
          policy = "bypass";
        }
        {
          domain = [ "wealthfolio.julesinabox.com" ];
          resources = [ "/manifest.json" ];
          policy = "bypass";
        }
      ];
    };
    session = {
      name = "authelia_session";
      expiration = "1h";
      inactivity = "5m";
      remember_me = "1M";
      cookies = [
        {
          domain = "munin.xyz";
          authelia_url = "https://auth.munin.xyz";
        }
      ];
    };
    regulation = {
      max_retries = "3";
      find_time = "2m";
      ban_time = "5m";
    };
    storage = {
      local = {
        path = "/config/db.sqlite3";
      };
    };
    notifier = {
      disable_startup_check = true;
      filesystem = {
        filename = "/tmp/authelia_notification.txt";
      };
    };
  };
in
{
  virtualisation.oci-containers.containers = {
    authelia = proxied {
      name = "authelia";
      host = "auth";
      auth = false;
      container = {
        image = "authelia/authelia:4";
        environment = {
          AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE = "/secrets/jwt-secret";
          AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE = "/secrets/storage-key";
          # Soft GC target below the --memory cap: the GC paces for 512MiB and the
          # 1G hard cap absorbs any overshoot (GOMEMLIMIT alone can be exceeded by
          # allocation bursts; see discussion #5939 for the spike pattern)
          GOMEMLIMIT = "512MiB";
        };
        extraOptions = [
          "--label=traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.munin.xyz/"
          "--label=traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
          "--label=traefik.http.middlewares.authelia.forwardauth.maxBodySize=1048576"
          "--label=traefik.http.middlewares.authelia.forwardauth.maxResponseBodySize=1048576"
          "--label=traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User, Remote-Groups, Remote-Name, Remote-Email"
          # Authelia has documented memory spikes (github.com/authelia/authelia/discussions/5939);
          # observed ~520MiB transient on top of a ~50MiB steady state
          "--memory=1G"
        ];
        volumes = [
          "/data/containers/authelia:/config"
          "${autheliaConfig}:/config/configuration.yml"
          "${autheliaUsers}:/config/users.yml"
          "${autheliaJwtSecret}:/secrets/jwt-secret:ro"
          "${autheliaStorageKey}:/secrets/storage-key:ro"
        ];
      };
    };
  };
}
