# Shared infrastructure tools package
# This can be imported by infrastructure repositories
{ pkgs, lib, ... }:

let
  # Define tool categories once to avoid duplication
  k8sCore = with pkgs; [
    kubectl
    helm
    kubectx
    k9s
    kustomize
  ];

  k8sExtended = with pkgs; [
    stern
    kubeseal
    argocd
  ];

  tofuCore = with pkgs; [
    opentofu
    terragrunt
  ];

  securityCore = with pkgs; [
    step-cli
    age
    sops
  ];

  monitoringCore = with pkgs; [
    grafana
    prometheus
  ];

in {
  # Core infrastructure management tools (comprehensive set)
  infrastructureTools = with pkgs;
    k8sCore
    ++ tofuCore
    ++ securityCore
    ++ monitoringCore
    ++ [
      # Talos Linux
      talosctl

      # Cloud providers
      awscli2
      google-cloud-sdk
      azure-cli

      # Container tools
      docker
      docker-compose
      podman
      skopeo

      # Network tools
      tailscale
      headscale
      hujsonfmt  # Tailscale's HuJSON formatter for policy files

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

  # Specialized tool categories (for selective imports)
  kubernetesTools = k8sCore ++ k8sExtended;

  tofuTools = tofuCore ++ (with pkgs; [
    tflint
    checkov
  ]);

  securityTools = securityCore ++ (with pkgs; [
    openbao  # Open-source fork of Vault
    cosign
    trivy
  ]);

  monitoringTools = monitoringCore ++ (with pkgs; [
    alertmanager
    blackbox_exporter
    node_exporter
  ]);
}
