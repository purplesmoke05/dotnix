{ lib
, stdenv
, callPackage
, fetchurl
, vscode-generic
, commandLineArgs ? ""
, useVSCodeRipgrep ? stdenv.hostPlatform.isDarwin
}:

let
  inherit (stdenv.hostPlatform) system;
  sources = lib.importJSON ./sources.json;
  source = sources.${system} or (throw "Unsupported system: ${system}");
  archiveFormat = if stdenv.hostPlatform.isDarwin then "zip" else "tar.gz";
  version = "1.108.1";
in
callPackage vscode-generic {
  pname = "vscode";
  executableName = "code";
  longName = "Visual Studio Code";
  shortName = "Code";

  inherit
    version
    commandLineArgs
    useVSCodeRipgrep
    ;

  src = fetchurl {
    name = "VSCode_${version}_${system}.${archiveFormat}";
    inherit (source) url hash;
  };

  tests = { };
  sourceRoot = "";
  updateScript = ./update.sh;
  dontFixup = stdenv.hostPlatform.isDarwin;
  hasVsceSign = true;

  meta = {
    description = "Code editor developed by Microsoft";
    mainProgram = "code";
    longDescription = ''
      Code editor developed by Microsoft. It includes support for debugging,
      embedded Git control, syntax highlighting, intelligent code completion,
      snippets, and code refactoring. It is also customizable, so users can
      change the editor's theme, keyboard shortcuts, and preferences.
    '';
    homepage = "https://code.visualstudio.com/";
    downloadPage = "https://code.visualstudio.com/Updates";
    license = lib.licenses.unfree;
    platforms = builtins.attrNames sources;
    maintainers = with lib.maintainers; [ ];
  };
}
