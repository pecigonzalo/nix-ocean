{
  lib,
  pkgs,
  proxied,
  ...
}:
let
  yamlFormat = pkgs.formats.yaml { };
  autheliaUsers = yamlFormat.generate "authelia-users.yml" {
    users = {
      weedv2 = {
        displayname = "Gonzalo";
        password = "$argon2id$v=19$m=1048576,t=1,p=8$N3VWY3pSTnMwWjZqd0VjQw$9JNHSWeW1WHpJxZoZS3jWAs5gG6fARzz5sp9/8MSry8";
        email = "weedv2@gmail.com";
        groups = [ "admins" ];
      };
      juliberas = {
        displayname = "Julieta";
        password = "$argon2id$v=19$m=65536,t=3,p=4$kjRe16hnpSmOFWnIOpoHXw$cDZmVCifihhOm0Q1xlQlV/J9+W6lXjc3RYdatp5Zxh0";
        email = "juliberas@outlook.com";
        groups = [ "users" ];
      };
    };
  };
  autheliaConfig = yamlFormat.generate "configuration.yml" {
    server = {
      host = "0.0.0.0";
      port = "9091";
      path = "";
    };
    log = {
      level = "info";
    };
    jwt_secret = "ThisRandomSecret!";

    totp = {
      issuer = "auth.julesinabox.com";
      period = "30";
      skew = "1";
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
            "^/api/. * $"
          ];
          policy = "bypass";
        }
      ];
    };
    session = {
      name = "authelia_session";
      expiration = "1h";
      inactivity = "5m";
      remember_me_duration = "1M";
      domain = "munin.xyz";
    };
    regulation = {
      max_retries = "3";
      find_time = "2m";
      ban_time = "5m";
    };
    storage = {
      encryption_key = "enamor-debunk-toggle-peruse";
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
        extraOptions = [
          "--label=traefik.http.middlewares.authelia.forwardauth.address=http://authelia:9091/api/verify?rd=https://auth.munin.xyz/"
          "--label=traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
          "--label=traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User, Remote-Groups, Remote-Name, Remote-Email"
          "--memory=2G"
        ];
        volumes = [
          "/data/containers/authelia:/config"
          "${autheliaConfig}:/config/configuration.yml"
          "${autheliaUsers}:/config/users.yml"
        ];
      };
    };
  };
}
