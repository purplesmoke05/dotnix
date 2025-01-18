{
  "terminal.integrated.defaultProfile.linux" = "fish";
  "terminal.integrated.profiles.linux" = {
    fish = {
      path = "fish";
      args = ["--login"];
    };
  };
  "editor.formatOnSave" = true;

  "window.commandCenter" = 1;
  "git.autofetch" = true;
  "git.confirmSync" = false;
  "explorer.confirmDelete" = false;
  "explorer.confirmDragAndDrop" = false;
  "nix.enableLanguageServer" = true;
  "nix.formatterPath" = [
    "nix"
    "fmt"
    "--"
    "-"
  ];
  "roo-cline.allowedCommands" = [
    "npm test"
    "npm install"
    "tsc"
    "git log"
    "git diff"
    "git show"
  ];
  "update.mode" = "none";
  "extensions.ignoreRecommendations" = true;
}