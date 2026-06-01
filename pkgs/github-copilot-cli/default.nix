{ lib
, stdenv
, autoPatchelfHook
, fetchurl
, makeBinaryWrapper
, bash
, versionCheckHook
}:

let
  version = "1.0.56";

  sources = {
    x86_64-linux = {
      name = "copilot-linux-x64";
      hash = "sha256-kwZozAvMlrOiLoGxU3NUTkNFxVOmc1HiQNY31wAmtUE=";
    };
    aarch64-linux = {
      name = "copilot-linux-arm64";
      hash = "sha256-toELKggTc/CZJdtt8BNsJNCT+oYLQwMcsQWkUD2yqEc=";
    };
    x86_64-darwin = {
      name = "copilot-darwin-x64";
      hash = "sha256-XsISntPe4Z+GLiO+jwpGaOfICHHm+0jxmob+0b2yCtA=";
    };
    aarch64-darwin = {
      name = "copilot-darwin-arm64";
      hash = "sha256-tHVOmHbilwLCEu7DzP9OW0I7APH+wprMYWdYj2dKeH8=";
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "github-copilot-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/github/copilot-cli/releases/download/v${finalAttrs.version}/${srcConfig.name}.tar.gz";
    inherit (srcConfig) hash;
  };

  nativeBuildInputs = [ makeBinaryWrapper ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];
  sourceRoot = ".";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 copilot $out/libexec/copilot
    runHook postInstall
  '';

  postInstall = ''
    makeWrapper $out/libexec/copilot $out/bin/copilot \
      --add-flags "--no-auto-update" \
      --prefix PATH : "${lib.makeBinPath [ bash ]}"
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = !stdenv.hostPlatform.isDarwin;

  meta = {
    description = "GitHub Copilot CLI brings the power of Copilot coding agent directly to your terminal";
    homepage = "https://github.com/github/copilot-cli";
    changelog = "https://github.com/github/copilot-cli/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.unfree;
    mainProgram = "copilot";
    platforms = lib.attrNames sources;
  };
})
