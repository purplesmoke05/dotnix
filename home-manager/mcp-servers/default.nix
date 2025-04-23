{ pkgs, lib, config, mcp-servers-nix, ... }:

let
  mcpConfig = mcp-servers-nix.lib.mkConfig pkgs {
    programs = {
      aws-kb-retrieval = { enable = false; /* Requires AWS credentials -> envFile/passwordCommand */ };
      brave-search = {
        enable = true; # Enable Brave Search
        # Requires API Key -> envFile/passwordCommand
        envFile = config.xdg.configHome + "/mcp-secrets/brave.env";
      };
      everart = { enable = true; };
      everything = { enable = true; };
      fetch = { enable = true; };
      filesystem = {
        enable = true; # Enable Filesystem
        # Requires allowed paths -> args
        args = [
          config.home.homeDirectory # Example: Allow access to home directory
          # Add other allowed paths here
        ];
      };
      gdrive = { enable = false; /* Add envFile/passwordCommand if needed */ };
      git = { enable = true; };
      github = {
        enable = true;
        envFile = config.xdg.configHome + "/mcp-secrets/github.env";
      };
      gitlab = { enable = false; /* Add envFile/passwordCommand if needed */ };
      google-maps = { enable = false; /* Add envFile/passwordCommand if needed */ };
      grafana = { enable = false; /* Add envFile/passwordCommand if needed */ };
      memory = { enable = true; };
      notion = { enable = false; /* Add envFile/passwordCommand if needed */ };
      playwright = { enable = true; };
      postgres = { enable = false; /* Add envFile/passwordCommand if needed */ };
      puppeteer = { enable = false; };
      redis = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sentry = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sequential-thinking = { enable = true; };
      slack = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sqlite = { enable = false; /* args = [ "/path/to/db.sqlite" ]; */ };
      time = { enable = true; };
    };

    # --- Security Note ---
    # Remember to configure sensitive modules (like github, gitlab, aws, etc.)
    # using `envFile` or `passwordCommand` for security.
    # Example:
    # programs.github.envFile = config.xdg.configHome + "/mcp-secrets/github.env";
    # programs.postgres.passwordCommand = { PGPASSWORD = ["pass", "postgres"]; };
  };
in
{
  # --- Place the generated config file ---
  # !! Verify the correct path for Cursor MCP config !!
  home.file.".cursor/mcp.json".source = mcpConfig;

  # Ensure the secret directory exists
  home.activation.secretsDir = lib.hm.dag.entryAfter [ "writeBoundary" ]
    ''
      mkdir -p ${config.xdg.configHome}/mcp-secrets
    '';
}
