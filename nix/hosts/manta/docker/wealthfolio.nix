{
  config,
  proxied,
  ...
}:
{
  virtualisation.oci-containers.containers = {
    wealthfolio = proxied {
      name = "wealthfolio";
      port = 8088;
      container = {
        image = "ghcr.io/wealthfolio/wealthfolio:latest";
        environment = {
          WF_MCP_ENABLED = "true";
          WF_DB_PATH = "/data/wealthfolio.db";
          WF_CORS_ALLOW_ORIGINS = "https://wealthfolio.munin.xyz";
        };
        environmentFiles = [
          config.age.secrets.wealthfolio.path
        ];
        volumes = [
          "/data/containers/wealthfolio/data:/data"
        ];
      };
    };
  };
}
