{
  accessibility = {
  dimUnfocused = {
  enabled = true;
};
};
  cursor = {
  cpp = {
  disabledLanguages = [
    "plaintext" "markdown" "scminput"
  ];
};
};
  diffEditor = {
  experimental = {
  useTrueInlineView = true;
};
  ignoreTrimWhitespace = false;
  maxComputationTime = 0;
};
  editor = {
  bracketPairColorization = {
  enabled = true;
};
  cursorBlinking = "expand";
  cursorSmoothCaretAnimation = "on";
  cursorStyle = "line-thin";
  dragAndDrop = false;
  formatOnSave = true;
  guides = {
  bracketPairs = true;
};
  minimap = {
  maxColumn = 80;
  showSlider = "always";
};
  renderLineHighlight = "all";
  renderLineHighlightOnlyWhenFocus = true;
  renderWhitespace = "all";
  showFoldingControls = "always";
  smoothScrolling = true;
  wordSegmenterLocales = "ja";
};
  explorer = {
  compactFolders = false;
  confirmDelete = false;
  confirmDragAndDrop = false;
  excludeGitIgnore = false;
  focusFirstFile = true;
};
  extensions = {
  ignoreRecommendations = true;
};
  files = {
  autoGuessEncoding = true;
  autoSave = "afterDelay";
  candidateGuessEncodings = [
    "utf8" "shiftjis" "eucjp"
  ];
  insertFinalNewline = false;
  trimFinalNewlines = true;
  trimTrailingWhitespace = true;
};
  git = {
  autofetch = "all";
  confirmSync = false;
  pruneOnFetch = true;
  suggestSmartCommit = false;
};
  motia = {
  autoStartServer = true;
};
  nix = {
  enableLanguageServer = false;
  formatterPath = [
    "nix" "fmt" "--" "-"
  ];
};
  roo-cline = {
  allowedCommands = [
    "npm test" "npm install" "tsc" "git log" "git diff" "git show" "nix-shell" "cd" "go" "git" "make" "cargo" "grep"
  ];
};
  rust-analyzer = {
  cargo = {
  buildScripts = {
  overrideCommand = [
    "cargo" "check" "--all-targets" "--quiet" "--workspace" "--all-features" "--message-format=json" "--jobs" "4"
  ];
};
};
  check = {
  overrideCommand = [
    "cargo" "check" "--all-targets" "--quiet" "--workspace" "--all-features" "--message-format=json" "--jobs" "4"
  ];
};
  checkOnSave = true;
  diagnostics = {
  disabled = [
    "unresolved-proc-macro" "inactive-code"
  ];
};
  inlayHints = {
  bindingModeHints = {
  enable = false;
};
  chainingHints = {
  enable = false;
};
};
  procMacro = {
  enable = true;
};
  restartServerOnConfigChange = true;
  showSyntaxTree = true;
};
  scm = {
  alwaysShowRepositories = true;
  compactFolders = false;
  defaultViewMode = "tree";
  diffDecorationsGutterWidth = 5;
  graph = {
  badges = "all";
};
  inputFontFamily = "editor";
  inputFontSize = 14;
};
  search = {
  searchEditor = {
  focusResultsOnSearch = true;
};
  seedOnFocus = true;
  showLineNumbers = true;
};
  terminal = {
  external = {
  linuxExec = "foot";
};
  integrated = {
  copyOnSelection = true;
  cursorBlinking = true;
  cursorStyle = "line";
  defaultProfile = {
  linux = "fish";
};
  enableImages = true;
  enableVisualBell = true;
  fontFamily = "Hack Nerd Font";
  fontSize = 12;
  fontWeight = "100";
  profiles = {
  linux = {
  fish = {
  args = [
    "--login"
  ];
  path = "fish";
};
};
};
  rightClickBehavior = "paste";
  scrollback = 10000;
  smoothScrolling = true;
};
};
  update = {
  mode = "none";
};
  window = {
  commandCenter = 1;
  customMenuBarAltFocus = false;
  menuBarVisibility = "hidden";
};
  workbench = {
  colorTheme = "Catppuccin Mocha";
  editor = {
  autoLockGroups = {
  terminalEditor = false;
};
  closeOnFileDelete = true;
  pinnedTabsOnSeparateRow = true;
  scrollToSwitchTabs = false;
  wrapTabs = false;
};
  iconTheme = "ayu";
  list = {
  smoothScrolling = true;
};
  tree = {
  expandMode = "doubleClick";
  indent = 24;
};
  view = {
  alwaysShowHeaderActions = true;
};
};
}