# Filtered Docker API for Traefik.
#
# Traefik used to mount /var/run/docker.sock directly. A read-only mount does not
# help: connecting to a Unix socket does not require write access, so an RCE in
# Traefik was host root via `docker run --privileged`.
#
# socket-proxy only allows the GET calls the Docker provider makes (plus the
# HEAD /_ping that Traefik >= 3.6 uses for API version negotiation), and only
# accepts connections from the traefik container. The `dockerapi` network is
# shared by exactly those two containers.
{
  config,
  ...
}:
{
  virtualisation.oci-containers.containers.socket-proxy = {
    image = "ghcr.io/wollomatic/socket-proxy:1.13.2";
    pull = "always";
    # Reads the socket as root:docker without running as root.
    user = "65534:${toString config.users.groups.docker.gid}";
    cmd = [
      "-loglevel=INFO"
      "-listenip=0.0.0.0"
      "-allowfrom=traefik"
      # Unversioned negotiation calls Traefik makes before it knows the version.
      "-allowGET=/(_ping|version)"
      "-allowGET=/v1\\..{1,2}/(version|info|containers.*|events.*|networks.*)"
      "-allowHEAD=/(_ping|version)"
      # Restart if the socket goes away (for example after a Docker upgrade).
      "-watchdoginterval=3600"
      "-stoponwatchdog"
      "-shutdowngracetime=5"
    ];
    extraOptions = [
      "--read-only"
      "--cap-drop=ALL"
      "--security-opt=no-new-privileges:true"
      "--memory=64M"
    ];
    volumes = [ "/var/run/docker.sock:/var/run/docker.sock:ro" ];
    networks = [ "dockerapi" ];
  };
}
