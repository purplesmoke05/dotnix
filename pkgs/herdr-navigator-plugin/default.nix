{ lib
, rustPlatform
, fetchFromGitHub
, writableTmpDirAsHomeHook
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "herdr-navigator-plugin";
  version = "0.3.6";

  src = fetchFromGitHub {
    owner = "thanhdat77";
    repo = "herdr-navigator";
    rev = "v${finalAttrs.version}";
    hash = "sha256-+xtBu4m2YenFH+W3Sv7atDvcsgChS5mKXgVgKomM768=";
  };

  cargoHash = "sha256-1fvQ8hyarP1WQwqIRvqKCkttwAMj3wGieue91/VNll8=";

  postPatch = ''
    substituteInPlace herdr-plugin.toml \
      --replace-fail $'[[build]]\ncommand = ["cargo", "build", "--release"]\n\n' "" \
      --replace-fail '"./target/release/herdr-navigator"' "\"$out/bin/herdr-navigator\""
  '';

  postInstall = ''
    cp README.md LICENSE CHANGELOG.md herdr-plugin.toml "$out/"
    cp -R examples "$out/"
  '';

  nativeInstallCheckInputs = [ writableTmpDirAsHomeHook ];
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -x "$out/bin/herdr-navigator"
    test "$(grep -Fc "\"$out/bin/herdr-navigator\"" "$out/herdr-plugin.toml")" -eq 5
    if grep -F '[[build]]' "$out/herdr-plugin.toml" >/dev/null; then
      echo "herdr-plugin.toml still contains a build hook" >&2
      exit 1
    fi
    if grep -F './target/release/herdr-navigator' "$out/herdr-plugin.toml" >/dev/null; then
      echo "herdr-plugin.toml still references the source build output" >&2
      exit 1
    fi
    "$out/bin/herdr-navigator" list >/dev/null
    runHook postInstallCheck
  '';

  passthru.pluginId = "herdr-navigator";

  meta = {
    description = "Fuzzy navigator for Herdr workspaces, agents, projects, sessions, and actions";
    homepage = "https://github.com/thanhdat77/herdr-navigator";
    changelog = "https://github.com/thanhdat77/herdr-navigator/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "herdr-navigator";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
