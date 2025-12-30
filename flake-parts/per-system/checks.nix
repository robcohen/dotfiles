# Flake checks
# Validates formatting, shell scripts, and YAML syntax
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        formatting =
          pkgs.runCommand "check-formatting"
            {
              buildInputs = [
                pkgs.nixfmt-rfc-style
                pkgs.findutils
              ];
            }
            ''
              cd ${self}
              # Check all nix files for formatting compliance
              find . -name "*.nix" -type f -print0 | xargs -0 nixfmt --check || {
                echo "Formatting issues found. Run 'nix fmt' to fix."
                exit 1
              }
              touch $out
            '';

        shellcheck =
          pkgs.runCommand "check-shellscripts"
            {
              buildInputs = [
                pkgs.shellcheck
                pkgs.findutils
              ];
            }
            ''
              cd ${self}
              # Check all shell scripts for common issues
              find assets/scripts -name "*.sh" -type f -print0 | xargs -0 shellcheck --severity=warning || {
                echo "Shell script issues found. Fix the issues above."
                exit 1
              }
              touch $out
            '';

        yaml-syntax =
          pkgs.runCommand "check-yaml-syntax"
            {
              buildInputs = [
                pkgs.yq-go
                pkgs.findutils
              ];
            }
            ''
              cd ${self}
              # Validate YAML syntax in docker-compose and config files
              for f in $(find hosts/wintv -name "*.yml" -o -name "*.yaml" 2>/dev/null); do
                yq eval '.' "$f" > /dev/null || {
                  echo "YAML syntax error in: $f"
                  exit 1
                }
              done
              touch $out
            '';
      };
    };
}
