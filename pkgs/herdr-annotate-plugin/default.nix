{ lib
, stdenv
, fetchFromGitHub
, fetchurl
, autoPatchelfHook
, writableTmpDirAsHomeHook
}:

let
  version = "0.9.9";
  revision = "a9973b43c1fc90044a9f15755e310e12b8465abb";
  # Native runtimes pinned by herdr-annotate.version and plannotator-tui.version. / herdr-annotate.version と plannotator-tui.version が固定する native runtime。
  annotateVersion = "0.2.3";
  plannotatorTuiVersion = "0.9.9";

  # Map Nix systems to release assets; x86_64 Linux takes the static musl TUI. / Nix system を release asset に対応付ける。x86_64 Linux の TUI は静的 musl 版を使う。
  sources = {
    x86_64-linux = {
      annotate = {
        asset = "herdr-annotate-x86_64-unknown-linux-gnu";
        hash = "sha256-BwNNKvDqHeEom+luWQy3XjF9TVmypjD74nrVxl9JnYE=";
      };
      tui = {
        asset = "plannotator-tui-x86_64-unknown-linux-musl";
        hash = "sha256-D9LNtbV1DcVJa9T/tv0lBUDA5/gsW0TTOTQ6JwFhUyA=";
      };
    };
    aarch64-linux = {
      annotate = {
        asset = "herdr-annotate-aarch64-unknown-linux-gnu";
        hash = "sha256-2Zh2xDSx53N5ZVmKgBONE00HEtGog82vAHsHsNeiXC0=";
      };
      tui = {
        asset = "plannotator-tui-aarch64-unknown-linux-gnu";
        hash = "sha256-VgaaedvyRYN7cjNEeEZFqnkAus3lx47Sfc9tEWCDcWE=";
      };
    };
    x86_64-darwin = {
      annotate = {
        asset = "herdr-annotate-x86_64-apple-darwin";
        hash = "sha256-YpaST9Js6gY/T3DYb5zkSqPypxDm6rR8npE1kbvkUdc=";
      };
      tui = {
        asset = "plannotator-tui-x86_64-apple-darwin";
        hash = "sha256-aLD5dL8U0hGj4qjgAf889H3K07u5Du0Mm0GUc61Oq6o=";
      };
    };
    aarch64-darwin = {
      annotate = {
        asset = "herdr-annotate-aarch64-apple-darwin";
        hash = "sha256-THoZvc7eUEeh+8fNkfs+AL7Vrvrxk6HwPX6q4BYq5wA=";
      };
      tui = {
        asset = "plannotator-tui-aarch64-apple-darwin";
        hash = "sha256-fh34dN2QX7hcgunbR1DRq2QAnUOAFz6me7yw5LydUls=";
      };
    };
  };

  srcConfig = sources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "herdr-annotate-plugin";
  inherit version;

  src = fetchFromGitHub {
    owner = "plannotator";
    repo = "herdr-annotate";
    rev = revision;
    hash = "sha256-H25wm/TuGho1u4b3ae/hzBMGGlGfcIfe5ywyaKk23gg=";
  };

  annotateBinary = fetchurl {
    url = "https://github.com/plannotator/herdr-annotate/releases/download/rust-lite-v${annotateVersion}/${srcConfig.annotate.asset}";
    inherit (srcConfig.annotate) hash;
  };

  plannotatorTuiBinary = fetchurl {
    url = "https://github.com/plannotator/plannotator-tui/releases/download/v${plannotatorTuiVersion}/${srcConfig.tui.asset}";
    inherit (srcConfig.tui) hash;
  };

  # Nix stages both runtimes, so drop the download hooks. / 両方の runtime を Nix が配置するため、ダウンロード用の build hook を外す。
  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail $'[[build]]\nplatforms = ["macos", "linux"]\ncommand = ["bash", "scripts/fetch-herdr-annotate.sh"]\n\n' "" \
      --replace-fail $'[[build]]\nplatforms = ["windows"]\ncommand = ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", "scripts/fetch-herdr-annotate.ps1"]\n\n' "" \
      --replace-fail $'[[build]]\nplatforms = ["macos", "linux"]\ncommand = ["bash", "scripts/fetch-plannotator-tui.sh"]\n\n' ""
  '';

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"
    cp -R . "$out/"
    install -Dm755 "$annotateBinary" "$out/bin/herdr-annotate.exe"
    install -Dm755 "$plannotatorTuiBinary" "$out/bin/plannotator-tui.exe"
    # Stamp the pins the way the upstream fetch scripts do. / upstream の fetch script と同じ形式で固定版を記録する。
    printf '%s\n' ${annotateVersion} > "$out/bin/herdr-annotate.version"
    printf '%s' ${plannotatorTuiVersion} > "$out/bin/plannotator-tui.version"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/herdr-plugin.toml"
    if grep -F '[[build]]' "$out/herdr-plugin.toml" >/dev/null; then
      echo "herdr-plugin.toml still contains a build hook" >&2
      exit 1
    fi
    # Fail the build when a source bump moves the upstream pins. / source の更新で upstream の固定版が動いたら build を失敗させる。
    test "$(tr -d '[:space:]' < "$out/herdr-annotate.version")" = ${annotateVersion}
    test "$(tr -d '[:space:]' < "$out/plannotator-tui.version")" = ${plannotatorTuiVersion}
    "$out/bin/herdr-annotate.exe" --version </dev/null >/dev/null
    "$out/bin/plannotator-tui.exe" --version </dev/null >/dev/null
    runHook postInstallCheck
  '';

  passthru.pluginId = "annotate";

  meta = {
    description = "Herdr terminal annotations and plannotator-tui review that send feedback back to agents";
    homepage = "https://github.com/plannotator/herdr-annotate";
    license = lib.licenses.mit;
    platforms = lib.attrNames sources;
  };
})
