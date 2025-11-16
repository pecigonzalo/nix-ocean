{ proxied, config, ... }:
let
  julesinaboxDomain = "julesinabox.com";
  thekiwidiariesDomain = "thekiwidiaries.com";
in
{
  virtualisation.oci-containers.containers = {
    wordpress-db = {
      image = "linuxserver/mariadb:latest";
      environment = {
        PUID = toString config.users.users.wordpress.uid;
        PGID = toString config.users.groups.wordpress.gid;
        MYSQL_ROOT_PASSWORD = "wordpress";
      };
      volumes = [
        "/data/containers/wordpress-db/config:/config"
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
      auth = false;
      container = {
        image = "wordpress:latest";
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        volumes = [
          "/data/containers/wordpress/www/julesinabox:/var/www/html"
        ];
        extraOptions = [
          "--label=traefik.http.routers.julesinabox.rule=Host(`${julesinaboxDomain}`) || Host(`www.${julesinaboxDomain}`)"
          "--memory=256M"
        ];
      };
    };
    portfolio = proxied {
      name = "portfolio";
      auth = false;
      container = {
        image = "wordpress:latest";
        user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
        volumes = [
          "/data/containers/wordpress/www/portfolio:/var/www/html"
        ];
        extraOptions = [
          "--label=traefik.http.routers.portfolio.rule=Host(`portfolio.${julesinaboxDomain}`) || Host(`www.portfolio.${julesinaboxDomain}`)"
          "--memory=256M"
        ];
      };
    };
    # Temporary Disable
    # tkd = proxied {
    #   name = "tkd";
    #   auth = false;
    #   container = {
    #     image = "wordpress:latest";
    #     user = "${toString config.users.users.wordpress.uid}:${toString config.users.groups.wordpress.gid}";
    #     volumes = [
    #       "/data/containers/wordpress/www/thekiwidiaries:/var/www/html"
    #     ];
    #     extraOptions = [
    #       "--label=traefik.http.routers.thekiwidiaries.rule=Host(`${thekiwidiariesDomain}`) || Host(`www.${thekiwidiariesDomain}`)"
    #     ];
    #   };
    # };
  };
}
