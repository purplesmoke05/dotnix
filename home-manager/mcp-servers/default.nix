{ pkgs, lib, config, mcp-servers-nix, ... }:

let
  mcpConfig = mcp-servers-nix.lib.mkConfig pkgs {
    programs = {
      aws-kb-retrieval = { enable = false; /* Requires AWS credentials -> envFile/passwordCommand */ };
      brave-search = {
        enable = true; # Brave Search (API key via envFile) / Brave Search（envFile に API キー）
        envFile = config.xdg.configHome + "/mcp-secrets/brave.env";
      };
      everart = {
        enable = false;
      };
      everything = { enable = true; };
      fetch = { enable = false; };
      filesystem = {
        enable = true; # Filesystem access / ファイルシステムアクセス
        args = [
          config.home.homeDirectory # Allow home directory / ホームディレクトリを許可
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
      playwright = { enable = false; }; # Disabled while libjxl fails / libjxl が壊れている間は無効
      postgres = { enable = false; /* Add envFile/passwordCommand if needed */ };
      puppeteer = { enable = false; };
      redis = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sentry = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sequential-thinking = { enable = true; };
      slack = { enable = false; /* Add envFile/passwordCommand if needed */ };
      sqlite = { enable = false; /* args = [ "/path/to/db.sqlite" ]; */ };
      time = { enable = false; };
    };

    # Security note / セキュリティ注意
    # Use envFile or passwordCommand for credentials. / 機密モジュールは envFile/passwordCommand で資格情報を供給。
  };
in
{
  # Cursor MCP config / Cursor 向け MCP 設定
  home.file.".cursor/mcp.json".source = mcpConfig;

  # Claude Code config / Claude Code 設定
  # ~/.claude/config.json でグローバルに共有。 / Shared globally via ~/.claude/config.json.
  home.file.".claude/config.json".source = mcpConfig;

  # Ensure secret directory / シークレット用ディレクトリを作成
  home.activation.secretsDir = lib.hm.dag.entryAfter [ "writeBoundary" ]
    ''
      mkdir -p ${config.xdg.configHome}/mcp-secrets
      mkdir -p ${config.home.homeDirectory}/.claude
    '';
}
