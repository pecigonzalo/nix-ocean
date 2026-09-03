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
  autheliaOidcHmacSecret = config.age.secrets.authelia-oidc-hmac-secret.path;
  autheliaOidcIssuerKey = config.age.secrets.authelia-oidc-issuer-key.path;
  autheliaOidcClientSecret = config.age.secrets.authelia-oidc-client-secret.path;

  autheliaConfig = yamlFormat.generate "configuration.yml" {
    server = {
      address = "tcp://0.0.0.0:9091/";
    };

    log = {
      level = "info";
    };

    totp = {
      issuer = "auth.munin.xyz";
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

  # Loaded after configuration.yml so the identity_providers section is layered
  # on top. The jwks key and the client secret use Authelia's file filter (enabled
  # with X_AUTHELIA_CONFIG_FILTERS=template) to inject the age-decrypted values at
  # runtime; the tokens must not be quoted by the YAML generator, so this file is
  # written by hand.
  autheliaOidcConfig = pkgs.writeText "configuration-oidc.yml" ''
    identity_providers:
      oidc:
        jwks:
          - key: {{ secret "/secrets/oidc-issuer-key" | mindent 10 "|" | msquote }}
        clients:
          # One shared secret across all OIDC clients to avoid a secret file per
          # client. Prefer public (PKCE) clients where the app supports it.
          - client_id: 'portainer'
            client_name: 'Portainer'
            client_secret: {{ secret "/secrets/oidc-client-secret" | msquote }}
            redirect_uris:
              - 'https://portainer.munin.xyz/portainer/oauth/oauth'
            scopes:
              - 'openid'
              - 'profile'
              - 'email'
              - 'groups'
  '';
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
          AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE = "/secrets/oidc-hmac-secret";
          # Enable template file filters so the JWKS key can be injected from a file
          X_AUTHELIA_CONFIG_FILTERS = "template";
        };
        cmd = [
          "--config"
          "/config/configuration.yml"
          "--config"
          "/config/oidc.yml"
        ];
        extraOptions = [
          "--label=traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.munin.xyz/"
          "--label=traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
          "--label=traefik.http.middlewares.authelia.forwardauth.maxBodySize=1048576"
          "--label=traefik.http.middlewares.authelia.forwardauth.maxResponseBodySize=1048576"
          "--label=traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User, Remote-Groups, Remote-Name, Remote-Email"
          # Authelia has documented memory spikes (github.com/authelia/authelia/discussions/5939);
          # observed ~520MiB during first OIDC activity on top of a ~50MiB steady state
          "--memory=1G"
        ];
        volumes = [
          "/data/containers/authelia:/config"
          "${autheliaConfig}:/config/configuration.yml"
          "${autheliaOidcConfig}:/config/oidc.yml"
          "${autheliaUsers}:/config/users.yml"
          "${autheliaJwtSecret}:/secrets/jwt-secret:ro"
          "${autheliaStorageKey}:/secrets/storage-key:ro"
          "${autheliaOidcHmacSecret}:/secrets/oidc-hmac-secret:ro"
          "${autheliaOidcIssuerKey}:/secrets/oidc-issuer-key:ro"
          "${autheliaOidcClientSecret}:/secrets/oidc-client-secret:ro"
        ];
      };
    };
  };
}
