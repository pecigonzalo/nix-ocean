{
  config,
  proxied,
  ...
}:
let
  julesinaboxDomain = "julesinabox.com";
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
      networks = [ "proxy" ];
      extraOptions = [
        "--pull=always"
        "--memory=512M"
      ];
      log-driver = "local";
    };

    # Both sites are unpublished for now. To publish one, give it a route, for
    # example:
    #   route = {
    #     rule = "Host(`julesinabox.com`) || Host(`www.julesinabox.com`)";
    #     authelia = false;
    #   };
    # They stay on the proxy network so they can reach wordpress-db by name.
    julesinabox = proxied {
      name = "julesinabox";
      container = {
        image = wordpressImage;
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        networks = [ "proxy" ];
        volumes = [
          "/data/containers/wordpress/www/julesinabox:/var/www/html"
        ];
        extraOptions = hardeningOptions ++ [ "--memory=256M" ];
      };
    };
    portfolio = proxied {
      name = "portfolio";
      container = {
        image = wordpressImage;
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        networks = [ "proxy" ];
        volumes = [
          "/data/containers/wordpress/www/portfolio:/var/www/html"
        ];
        extraOptions = hardeningOptions ++ [ "--memory=256M" ];
      };
    };
  };
}
