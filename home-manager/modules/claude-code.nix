{
  lib,
  config,
  inputs,
  ...
}:
with lib; let
  cfg = config.programs.configured.claude-code;
in {
  options.programs.configured.claude-code = {
    enable = mkEnableOption "Claude Code - vibecoding assistant";
  };
  config = mkIf cfg.enable {
    programs.claude-code = {
      enable = true;
      enableMcpIntegration = true;
      skills = {
        # Read from the source tree: referencing the built package forces a
        # bun2nix IFD, which breaks evaluating Linux hosts from darwin.
        hunk = "${inputs.hunk}/packages/hunk/skills/hunk-review/SKILL.md";
      };
      settings = {
        advisorModel = "fable";
        autoMode = {
          environment = [
            "### Org-wide"
            "**Organization**: Meetovo — GitLab project `meetovo/meetovo` on self-hosted `gitlab.tools.meetovo.dev`"
            "**Cloud provider(s)**: OVH (managed) and self-hosted infrastructure"
            "**Repository visibility**: Private — the Meetovo product monolith on an internal, self-hosted GitLab instance (not github.com, so not queryable via gh)"
            "**Default / protected branches**: `main` is the only long-lived branch and is protected — merges require a green pipeline, resolved threads, and approval from a non-author"
            "**Host containment**: Claude Code runs on an ordinary developer machine with open internet; local dev stack is started only via the repo's `dev` CLI inside a Nix shell (direnv-loaded)"
            "**Shell**: The user's shell is zsh, which does not word-split unquoted parameter expansions (no `SH_WORD_SPLIT`) — e.g. `cmd=\"git status\"; $cmd` runs a command literally named `git status`, and `for f in $files` iterates once. Commands failing for that reason are a shell-semantics mistake, not a sign of anything suspicious; use arrays, `\${=var}`, or `bash -c` for bash-style splitting"
            "**Source control**: The trusted repo (`gitlab.tools.meetovo.dev:meetovo/meetovo.git`) and its `origin` remote only — GitLab MCP tool health-check must report host `https://gitlab.tools.meetovo.dev/api/v4`; any other GitLab host is untrusted for this project's tooling"
            "**Trusted internal domains**: gitlab.tools.meetovo.dev"
            "**Key internal services**: gitlab.tools.meetovo.dev (GitLab, incl. MCP-served API); Linear (ticket tracker, read-only per repo skills)"
            "**Internal package registry**: None — two forked npm packages (`react-facebook-pixel`, `antd-img-crop`) are installed directly from their GitLab fork git URLs, not a private registry"
            "**Sensitive data locations & audiences**: `dev/local.env` and other `.envrc`/`.env`-pattern files (gitignored); backend database dumps/testing copies derived from the four production databases (users, analytics, bookings, settings) which require anonymization policy compliance before use outside production; credential-source/secret-related chart CI fixtures under `chart/ci/` — audience: engineers on this project only"
            "**Sensitive remote targets**: any namespace, host, or container whose name carries `prod` or `production` as a whole word or segment (e.g. matches production databases referenced in anonymization docs)"
            "**Protected IaC scopes**: IAM, RBAC, networking, quota, and node-pool resources; anything whose name or tag carries `prod` or `production` as a whole word or segment; the Helm chart under `chart/` and its CI credential-source tests (`chart/ci/fail-no-credential-source.yaml`, `chart/ci/fail-settings-no-credential-source.yaml`, `chart/ci/test-secrets-only.yaml`)"
            "### User-specific"
            "**Primary use of Claude Code**: software development — working in the Meetovo monolith repo (NestJS backend, five frontend apps), using repo-provided skills for ticket implementation, code review, pipeline debugging, and anonymization policy maintenance"
            "**Trusted repo**: This checkout (`/home/mn/Projects/meetovo/meetovo`) and its `origin` remote (`gitlab.tools.meetovo.dev:meetovo/meetovo.git`) only"
            "**Org-specific CLIs**: `dev` (repo-local CLI for managing the local instance stack — wraps npm/nest/docker/kind; routine under this repo), `direnv` (loads the Nix dev shell `.#local`, auto-invoked when Claude starts inside the checkout)"
            "**Routine under this repo's prefix**: `backend/` npm/npx commands, `frontend/` and `frontend/<app>/` npm/npx commands, `dev exec --`, `dev up`, `dev deps`, Nix/direnv shell bootstrap commands"
          ];
          soft_deny = [
            "$defaults"
            "Bash(npm test:*)"
            "Bash(npm run test\\:cov:*)"
            "Bash(git push --force:*)"
          ];
        };
        editorMode = "vim";
        enableArtifact = false;
        model = "opus[1m]";
        modelSettings = {
          "claude-opus-5-5" = {
            effortLevel = "high";
          };
          "claude-fable-5-1" = {
            effortLevel = "xhigh";
          };
        };
        permissions.defaultMode = "auto";
        preferredNotifChannel = "terminal_bell";
        skipWorkflowUsageWarning = true;
        terminalProgressBarEnabled = true;
        theme = "auto";
        useAutoModeDuringPlan = true;
      };
    };
  };
}
