# Shared infrastructure configurations
# Standard configurations that can be imported by infrastructure repos
{ pkgs, lib, ... }:

let
  # Common environment variables (defined here so direnvTemplate can reference it)
  environmentVariables = {
    KUBECONFIG = "$HOME/.kube/config";
    TALOSCONFIG = "$HOME/.talos/config";
    TERRAFORM_LOG = "WARN";
    HELM_CACHE_HOME = "$HOME/.cache/helm";
    ARGOCD_OPTS = "--insecure";
  };
in
{
  # Standard kubectl configuration template
  kubectlConfig = {
    apiVersion = "v1";
    kind = "Config";
    preferences = {};
    clusters = [
      {
        cluster = {
          server = "https://management.internal.example.com:6443";
          certificate-authority = "/etc/ssl/certs/ca-root.crt";
        };
        name = "management";
      }
    ];
    contexts = [
      {
        context = {
          cluster = "management";
          user = "developer";
        };
        name = "management";
      }
    ];
    current-context = "management";
    users = [
      {
        name = "developer";
        user = {
          client-certificate = "~/.kube/client.crt";
          client-key = "~/.kube/client.key";
        };
      }
    ];
  };

  # Standard Terraform configuration
  terraformConfig = {
    terraform = {
      required_version = ">= 1.0";
      required_providers = {
        kubernetes = {
          source = "hashicorp/kubernetes";
          version = "~> 2.0";
        };
        helm = {
          source = "hashicorp/helm";
          version = "~> 2.0";
        };
      };
    };
  };

  # Common shell aliases for infrastructure work
  shellAliases = {
    # Kubernetes
    k = "kubectl";
    kx = "kubectx";
    kns = "kubens";
    kg = "kubectl get";
    kd = "kubectl describe";
    kl = "kubectl logs";
    ke = "kubectl exec -it";

    # Terraform
    tf = "terraform";
    tfa = "terraform apply";
    tfp = "terraform plan";
    tfi = "terraform init";

    # Infrastructure
    tg = "terragrunt";
    hm = "helm";
    argocd = "argocd --insecure";
  };

  # Re-export environment variables for consumers
  inherit environmentVariables;

  # Standard direnv template
  direnvTemplate = ''
    # Infrastructure project environment
    if has nix; then
      if [[ -f flake.nix ]]; then
        echo "🔧 Loading project-specific tools..."
        use flake
      else
        echo "🔧 Loading infrastructure tools from dotfiles..."
        use flake github:robcohen/dotfiles#infrastructure
      fi
    fi

    # Standard environment variables
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: value: "export ${name}=\"${value}\"") environmentVariables)}

    # Infrastructure environment indicator
    export DIRENV_INFRA=1
  '';
}
