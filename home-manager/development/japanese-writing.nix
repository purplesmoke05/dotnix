{ pkgs, ... }:

let
  writingRules = ./japanese-writing/rules.md;
  # Fetch the full guideline instead of committing it, because its source states no license. / 出典にライセンスの記載がないため、全文はコミットせずに取得する。
  humanizerGuideline = pkgs.fetchurl {
    url = "https://imoz.jp/humanizer.ja.txt";
    hash = "sha256-R8D1ei/XyXx9DIogSCRdvoxkgrBRqiB0xK/rexY9Ne4=";
  };
  humanizerSkill = pkgs.runCommand "humanizer-ja-skill" { } ''
    install -Dm644 ${./japanese-writing/humanizer-ja/SKILL.md} "$out/SKILL.md"
    install -Dm644 ${humanizerGuideline} "$out/references/humanizer.ja.txt"
  '';
  yomiyasuSource = pkgs.fetchFromGitHub {
    owner = "nanaism";
    repo = "yomiyasu";
    rev = "v1.0.8";
    hash = "sha256-Iatj0iqlzi33CBla44IEe3n300aY8oqx1kAV7daWCrU=";
  };
  # Keep yomiyasu explicit-only so it does not compete with humanizer-ja. / humanizer-ja と競合しないよう、yomiyasu は名前で呼んだときだけ使う。
  yomiyasuSkill = pkgs.runCommand "yomiyasu-skill" { } ''
    cp -r ${yomiyasuSource}/skills/yomiyasu "$out"
    chmod -R u+w "$out"
    sed '/^name: yomiyasu$/a disable-model-invocation: true' ${yomiyasuSource}/SKILL.md > "$out/SKILL.md"
    grep -qx 'disable-model-invocation: true' "$out/SKILL.md"
    mkdir -p "$out/agents"
    cat > "$out/agents/openai.yaml" <<'EOF'
    policy:
      allow_implicit_invocation: false
    EOF
  '';
in
{
  home.file = {
    # Claude Code and Pi read these files in every session. / Claude Code と Pi は毎セッションこのファイルを読む。
    ".claude/CLAUDE.md".source = writingRules;
    ".pi/agent/AGENTS.md".source = writingRules;
    # Codex and Pi read ~/.agents/skills; Claude Code reads ~/.claude/skills. / Codex と Pi は ~/.agents/skills、Claude Code は ~/.claude/skills を読む。
    ".agents/skills/humanizer-ja" = {
      source = humanizerSkill;
      recursive = true;
    };
    ".claude/skills/humanizer-ja" = {
      source = humanizerSkill;
      recursive = true;
    };
    ".agents/skills/yomiyasu" = {
      source = yomiyasuSkill;
      recursive = true;
    };
    ".claude/skills/yomiyasu" = {
      source = yomiyasuSkill;
      recursive = true;
    };
  };
}
