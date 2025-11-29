{ config, proxied, ... }:
let
  ghost_db_password = "ab0ddc68f8af49cdc11e98d1f9945f8c47a4044c402ffacbadfff686f5dc7ca8";
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
        MARIADB_ROOT_PASSWORD = ghost_db_password;
      };
      volumes = [
        "/data/containers/ghost-db/config:/config"
      ];
      extraOptions = [
        "--pull=always"
        "--network=proxy"
      ];
      log-driver = "local";
    };
  };
}
