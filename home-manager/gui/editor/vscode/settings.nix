{
  "[dockercompose]" = {
  editor = {
  autoIndent = "advanced";
  defaultFormatter = "redhat.vscode-yaml";
  insertSpaces = true;
  tabSize = 2;
};
};
  "[github-actions-workflow]" = {
  editor = {
  defaultFormatter = "redhat.vscode-yaml";
};
};
  "[markdown]" = {
  cSpell = {
  advanced = {
  feature = {
  useReferenceProviderRemove = "/^#+\\s/";
  useReferenceProviderWithRename = true;
};
};
  fixSpellingWithRenameProvider = true;
};
  diffEditor = {
  ignoreTrimWhitespace = false;
};
  editor = {
  defaultFormatter = "DavidAnson.vscode-markdownlint";
  quickSuggestions = {
  comments = "off";
  other = "off";
  strings = "off";
};
  unicodeHighlight = {
  ambiguousCharacters = false;
  invisibleCharacters = false;
};
  wordWrap = "off";
};
};
  accessibility = {
  dimUnfocused = {
  enabled = true;
};
};
  cSpell = {
  caseSensitive = true;
  diagnosticLevel = "Warning";
  diagnosticLevelFlaggedWords = "Warning";
  userWords = [
    "survlink"
  ];
};
  chat = {
  editing = {
  confirmEditRequestRemoval = false;
};
};
  cursor = {
  composer = {
  shouldChimeAfterChatFinishes = true;
  textSizeScale = 0.85;
};
  cpp = {
  disabledLanguages = [
    "plaintext" "markdown" "scminput"
  ];
};
  terminal = {
  usePreviewBox = true;
};
};
  diffEditor = {
  experimental = {
  useTrueInlineView = false;
};
  ignoreTrimWhitespace = false;
  maxComputationTime = 0;
};
  docker = {
  extension = {
  enableComposeLanguageServer = false;
};
};
  editor = {
  accessibilitySupport = "off";
  bracketPairColorization = {
  enabled = true;
};
  cursorBlinking = "expand";
  cursorSmoothCaretAnimation = "off";
  cursorStyle = "line-thin";
  dragAndDrop = false;
  experimental = {
  asyncTokenization = false;
};
  formatOnSave = true;
  guides = {
  bracketPairs = true;
};
  minimap = {
  enabled = false;
  maxColumn = 80;
  showSlider = "always";
};
  renderLineHighlight = "all";
  renderLineHighlightOnlyWhenFocus = true;
  renderWhitespace = "all";
  showFoldingControls = "always";
  smoothScrolling = false;
  wordSegmenterLocales = "ja";
  wordWrap = "off";
};
  explorer = {
  autoReveal = false;
  compactFolders = false;
  confirmDelete = false;
  confirmDragAndDrop = false;
  excludeGitIgnore = false;
  focusFirstFile = false;
  openEditors = {
  visible = 0;
};
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
  watcherExclude = {
  "" = {
  "git/objects/**" = true;
  "git/subtree-cache/**" = true;
};
  "**/node_modules/**" = true;
};
};
  git = {
  autofetch = "all";
  confirmSync = false;
  pruneOnFetch = true;
  suggestSmartCommit = false;
};
  github = {
  copilot = {
  enable = {
  "*" = true;
  markdown = true;
  nextEditSuggestions = {
  enabled = true;
};
  plaintext = false;
  scminput = false;
};
  nextEditSuggestions = {
  enabled = true;
};
};
};
  go = {
  toolsManagement = {
  autoUpdate = true;
};
};
  markdownlint = {
  run = "onSave";
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
  python = {
  analysis = {
  autoFormatStrings = true;
  autoImportCompletions = true;
  completeFunctionParens = true;
  diagnosticMode = "workspace";
  displayEnglishDiagnostics = true;
  typeCheckingMode = "strict";
};
};
  roo-cline = {
  allowedCommands = [
    "npm test" "npm install" "tsc" "git log" "git diff" "git show" "nix-shell" "cd" "go" "git" "make" "cargo" "grep"
  ];
};
  remote = {
    SSH = {
      remoteCommand = "/run/current-system/sw/bin/bash -l";
    };
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
  smoothScrolling = false;
};
};
  update = {
  mode = "none";
  releaseTrack = "prerelease";
};
  window = {
  commandCenter = 1;
  customMenuBarAltFocus = false;
  experimental = {
  useGpuAcceleration = true;
};
  menuBarVisibility = "hidden";
  titleBarStyle = "custom";
  zoomLevel = -1;
};
  workbench = {
  colorTheme = "Catppuccin Mocha";
  editor = {
  autoLockGroups = {
  terminalEditor = false;
};
  closeOnFileDelete = true;
  experimentalAutoLayout = false;
  pinnedTabsOnSeparateRow = true;
  scrollToSwitchTabs = false;
  wrapTabs = false;
};
  editorUnnecessaryCode = {
  border = "#f0f";
  opacity = "#000c";
};
  iconTheme = "ayu";
  list = {
  openMode = "doubleClick";
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
