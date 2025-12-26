# Shared infrastructure tools package
# This can be imported by infrastructure repositories
{ pkgs, lib, ... }:

{
  # Core infrastructure management tools
  infrastructureTools = with pkgs; [
    # Kubernetes ecosystem
    kubectl
    helm
    kubectx
    k9s
    kustomize

    # Talos Linux
    talosctl

    # Infrastructure as Code
    opentofu
    terragrunt

    # Cloud providers
    awscli2
    google-cloud-sdk
    azure-cli

    # Container tools
    docker
    docker-compose
    podman
    skopeo

    # Security tools
    step-cli
    age
    sops

    # Network tools
    tailscale
    headscale
    hujsonfmt  # Tailscale's HuJSON formatter for policy files

    # Monitoring tools
    grafana
    prometheus

    # Development tools
    jq
    yq-go
    curl
    wget
    git

    # Shell utilities
    fzf
    ripgrep
    bat
    eza
    fd
  ];

  # Specialized tool categories
  kubernetesTools = with pkgs; [
    kubectl
    helm
    kubectx
    k9s
    kustomize
    stern
    kubeseal
    argocd
  ];

  tofuTools = with pkgs; [
    opentofu
    terragrunt
    tflint
    checkov
  ];

  securityTools = with pkgs; [
    step-cli
    age
    sops
    openbao  # Open-source fork of Vault
    cosign
    trivy
  ];

  monitoringTools = with pkgs; [
    grafana
    prometheus
    alertmanager
    blackbox_exporter
    node_exporter
  ];
}
