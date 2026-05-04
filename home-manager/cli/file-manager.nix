{ pkgs, ... }:

{
  # Terminal file managers / ターミナルファイルマネージャ
  programs.yazi = {
    enable = true;
    package = pkgs.yazi.override { optionalDeps = [ ]; };
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableNushellIntegration = true;
    shellWrapperName = "yy";

    extraPackages = with pkgs; [
      bat
      eza
      fd
      fzf
      glow
      ouch
      rich-cli
      ripgrep
      xlsx2csv
    ];

    plugins = {
      piper = pkgs.yaziPlugins.piper;
      "rich-preview" = pkgs.yaziPlugins."rich-preview";
      ouch = pkgs.yaziPlugins.ouch;
      "full-border" = pkgs.yaziPlugins."full-border";
    };

    initLua = ''
      require("full-border"):setup()
    '';

    settings = {
      mgr = {
        show_hidden = true;
        sort_dir_first = true;
      };

      opener.extract = [
        {
          run = "ouch d -y \"$@\"";
          desc = "Extract here with ouch";
          for = "unix";
        }
      ];

      plugin.prepend_previewers = [
        { name = "*.xlsx"; run = "piper -- xlsx2csv -a \"$1\" | sed -n '1,240p'"; }
        { name = "*.xlsm"; run = "piper -- xlsx2csv -a \"$1\" | sed -n '1,240p'"; }
        { name = "*.csv"; run = "rich-preview"; }
        { name = "*.json"; run = "rich-preview"; }
        { name = "*.md"; run = "rich-preview"; }
        { name = "*.rst"; run = "rich-preview"; }
        { name = "*.ipynb"; run = "rich-preview"; }
        { mime = "application/{*zip,tar,bzip2,7z*,rar,xz,zstd,java-archive}"; run = "ouch --show-file-icons"; }
      ];
    };
  };

  programs.superfile = {
    enable = true;
    firstUseCheck = false;
    settings = {
      metadata = true;
      zoxide_support = true;
      show_image_preview = true;
    };
    pinnedFolders = [
      {
        name = "Nix config";
        location = "/home/purplehaze/.nix";
      }
      {
        name = "Home";
        location = "/home/purplehaze";
      }
    ];
  };
}
