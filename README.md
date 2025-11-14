# NixOS Modular Configuration

This repository contains a modular NixOS configuration structure designed for easy reuse across multiple hosts.

## Repository Organization

### Core Concepts

**Hosts Directory (`hosts/`)**

- Each host has its own directory with `default.nix` and `hardware-configuration.nix`
- Grouped hosts (like clusters) can share a common `default.nix` at the group level
- Individual hosts import what they need (either group config or modules directly)

**Modules Directory (`modules/`)**

- `common/`: Base system functionality (boot, SSH, Nix daemon, performance, users)
- `roles/`: Host purpose definitions (cluster node, router, etc.)

### Organization Patterns

**Pattern 1: Grouped Hosts** (e.g., reef cluster)

```
hosts/group/
├── default.nix         # Shared config for all group members
└── hostname/
    ├── default.nix     # Imports ../default.nix + host-specific config
    └── hardware-configuration.nix
```

**Pattern 2: Standalone Hosts** (e.g., unique routers)

```
hosts/hostname/
├── default.nix         # Imports modules directly
└── hardware-configuration.nix
```

**Key Principle:** Group hosts when they share identical base configuration. Keep standalone when unique.

## Host Configuration

### Current Hosts

Run `nix flake show` to see all configured hosts.

### Reef Cluster Nodes

Coordinated cluster with shared base configuration:

- Located in `hosts/reef/`
- Share common imports via `hosts/reef/default.nix`
- Only differ in hostname and network settings (IP, MAC)

### Standalone Hosts

Independent systems with unique configurations:

- Located at `hosts/<hostname>/`
- Import modules directly
- Used for routers, special-purpose nodes, or hosts with different requirements

All cluster nodes use the `cluster` role and share base system configuration (SSH, packages, performance tuning).

## Deployment

### Using Nix Flake Apps (Recommended)

The flake includes deployment apps that require zero external dependencies:

```bash
# List all available apps
nix flake show

nix run .#deploy-$host         # Deploy host
nix run .#deploy-all          # Deploy all reef cluster nodes (beta, guppy, tetra, manta)

# Build without deploying (test configuration)
nix run .#build-$host
```

All deployments build on the target host itself (each host builds its own configuration).
