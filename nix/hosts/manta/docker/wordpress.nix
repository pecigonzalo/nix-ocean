{
  config,
  lib,
  proxied,
  ...
}:
let
  julesinaboxDomain = "julesinabox.com";
  thekiwidiariesDomain = "thekiwidiaries.com";
  wordpressDbPassword = config.age.secrets.wordpress-db-password.path;
  # Explicit PHP branch: `wordpress:latest` tracks the oldest supported PHP (8.3).
  wordpressImage = "wordpress:php8.5-apache";
  # Apache binds :80 for an unprivileged user, so that is the only capability
  # it needs; drop the rest and block setuid/setgid escalation.
  hardeningOptions = [
    "--security-opt=no-new-privileges:true"
    "--cap-drop=ALL"
    "--cap-add=NET_BIND_SERVICE"
  ];
  exposeWordpress = false;
in
{
  virtualisation.oci-containers.containers = {
    wordpress-db = {
      image = "linuxserver/mariadb:latest";
      environment = {
        PUID = toString config.users.users.wordpress.uid;
        PGID = toString config.users.groups.wordpress.gid;
        FILE__MYSQL_ROOT_PASSWORD = "/secrets/db-password";
      };
      volumes = [
        "/data/containers/wordpress-db/config:/config"
        "${wordpressDbPassword}:/secrets/db-password:ro"
      ];
      extraOptions = [
        "--pull=always"
        "--network=proxy"
        "--memory=512M"
      ];
      log-driver = "local";
    };

    julesinabox = proxied {
      name = "julesinabox";
      proxy = exposeWordpress;
      auth = false;
      container = {
        image = wordpressImage;
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        volumes = [
          "/data/containers/wordpress/www/julesinabox:/var/www/html"
        ];
        extraOptions =
          lib.optional exposeWordpress "--label=traefik.http.routers.julesinabox.rule=Host(`${julesinaboxDomain}`) || Host(`www.${julesinaboxDomain}`)"
          ++ hardeningOptions
          ++ [ "--memory=256M" ];
      };
    };
    portfolio = proxied {
      name = "portfolio";
      proxy = exposeWordpress;
      auth = false;
      container = {
        image = wordpressImage;
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        volumes = [
          "/data/containers/wordpress/www/portfolio:/var/www/html"
        ];
        extraOptions =
          lib.optional exposeWordpress "--label=traefik.http.routers.portfolio.rule=Host(`portfolio.${julesinaboxDomain}`) || Host(`www.portfolio.${julesinaboxDomain}`)"
          ++ hardeningOptions
          ++ [ "--memory=256M" ];
      };
    };
    # Temporary Disable
    # tkd = proxied {
    #   name = "tkd";
    #   auth = false;
    #   container = {
    #     image = wordpressImage;
    #     user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
    #     volumes = [
    #       "/data/containers/wordpress/www/thekiwidiaries:/var/www/html"
    #     ];
    #     extraOptions = [
    #       "--label=traefik.http.routers.thekiwidiaries.rule=Host(`${thekiwidiariesDomain}`) || Host(`www.${thekiwidiariesDomain}`)"
    #     ] ++ hardeningOptions;
    #   };
    # };
  };
}
