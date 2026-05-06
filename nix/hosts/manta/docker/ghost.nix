{ config, proxied, ... }:
let
  ghost_db_password = config.age.secrets.ghost-db-password.path;
in
{
  virtualisation.oci-containers.containers = {
    ghost = proxied {
      name = "ghost";
      host = "hugin";
      auth = false;
      container = {
        image = "ghost:5";
        environment = {
          url = "https://hugin.munin.xyz";
          database__client = "mysql";
          database__connection__host = "ghost-db";
          database__connection__database = "ghost";
          database__connection__user = "root";
          database__connection__password = ghost_db_password;
        };
        extraOptions = [
          "--memory=128M"
        ];
      };
    };
    ghost-db = {
      image = "mariadb:10";
      environment = {
        MARIADB_DATABASE = "ghost";
        MARIADB_ROOT_PASSWORD_FILE = "/secrets/db-password";
      };
      volumes = [
        "/data/containers/ghost-db/config:/config"
        "${ghost_db_password}:/secrets/db-password:ro"
      ];
      extraOptions = [
        "--pull=always"
        "--network=proxy"
      ];
      log-driver = "local";
    };
  };
}
