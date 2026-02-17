import argparse
import json
import platform
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUT = SCRIPT_DIR / "zed-keymap.json"
DEFAULT_AUTO_OUTPUT = SCRIPT_DIR / "zed-keymap-auto.json"
DEFAULT_REPORT = SCRIPT_DIR / "zed-keymap-report.md"
DEFAULT_EMACS_BASE = SCRIPT_DIR / "zed-keymap-emacs-base.json"
DEFAULT_MANUAL_OVERRIDES = SCRIPT_DIR / "zed-keymap-manual.json"

MODIFIER_ORDER = ["ctrl", "alt", "shift", "cmd", "super"]
MODIFIER_ALIASES = {
    "ctrl": "ctrl",
    "control": "ctrl",
    "alt": "alt",
    "option": "alt",
    "shift": "shift",
    "cmd": "cmd",
    "command": "cmd",
    "meta": "cmd",
    "win": "super",
    "windows": "super",
    "super": "super",
}
KEY_ALIASES = {
    "esc": "escape",
    "return": "enter",
    "del": "delete",
    "pgup": "pageup",
    "pgdn": "pagedown",
    "spacebar": "space",
    "ins": "insert",
    "equal": "=",
    "minus": "-",
    "semicolon": ";",
    "quote": "'",
    "backquote": "`",
    "slash": "/",
    "backslash": "\\",
    "intlbackslash": "\\",
    "intlyen": "\\",
}
EDITOR_WHEN_TOKENS = [
    "editorfocus",
    "editortextfocus",
    "editorhasselection",
    "editorhasmultipleselections",
    "findwidgetvisible",
    "inputfocus",
    "inreferencesearcheditor",
    "parameterhintsvisible",
    "renameinputvisible",
    "suggestwidgetvisible",
    "textinputfocus",
]
PROJECT_WHEN_TOKENS = [
    "explorerviewlet",
    "explorerviewletfocus",
    "explorerresource",
    "filesexplorerfocus",
]
MENU_WHEN_TOKENS = [
    "listfocus",
    "inquickopen",
]


COMMAND_MAP: Dict[str, Any] = {
    "actions.find": "buffer_search::Deploy",
    "actions.findWithSelection": "buffer_search::Deploy",
    "aichat.newchataction": "agent::NewTextThread",
    "aipopup.action.modal.generate": "assistant::InlineAssist",
    "cancelLinkedEditingInput": "editor::Cancel",
    "cancelRenameInput": "editor::Cancel",
    "cancelSelection": "editor::Cancel",
    "closeAccessibilityHelp": "editor::Cancel",
    "closeFindWidget": "buffer_search::Dismiss",
    "closeReferenceSearch": "editor::Cancel",
    "closeReplaceInFilesWidget": "editor::Cancel",
    "commentsClearFilterText": "editor::Cancel",
    "composer.newAgentChat": "agent::NewThread",
    "cursorUp": "editor::MoveUp",
    "deleteLeft": "editor::Backspace",
    "deleteWordLeft": "editor::DeleteToPreviousWordStart",
    "deleteWordPartLeft": "editor::DeleteToPreviousSubwordStart",
    "deleteWordPartRight": "editor::DeleteToNextSubwordEnd",
    "deleteWordRight": "editor::DeleteToNextWordEnd",
    "editor.action.clipboardPasteAction": "editor::Paste",
    "editor.action.deleteLines": "editor::DeleteLine",
    "editor.action.inlineSuggest.hide": "editor::Cancel",
    "editor.action.nextMatchFindAction": "search::SelectNextMatch",
    "editor.action.outdentLines": "editor::Outdent",
    "editor.action.quickFix": "editor::ToggleCodeActions",
    "editor.action.rename": "editor::Rename",
    "editor.action.selectAll": "editor::SelectAll",
    "editor.action.startFindReplaceAction": "buffer_search::DeployReplace",
    "editor.action.triggerSuggest": "editor::ShowCompletions",
    "editor.action.webvieweditor.hideFind": "buffer_search::Dismiss",
    "editor.cancelOperation": "editor::Cancel",
    "editor.closeCallHierarchy": "editor::Cancel",
    "editor.debug.action.toggleBreakpoint": "editor::ToggleBreakpoint",
    "editor.fold": "editor::Fold",
    "editor.foldLevel1": "editor::FoldAtLevel_1",
    "editor.foldLevel2": "editor::FoldAtLevel_2",
    "editor.foldLevel3": "editor::FoldAtLevel_3",
    "editor.foldLevel4": "editor::FoldAtLevel_4",
    "editor.foldLevel5": "editor::FoldAtLevel_5",
    "editor.foldLevel6": "editor::FoldAtLevel_6",
    "editor.foldLevel7": "editor::FoldAtLevel_7",
    "editor.unfold": "editor::UnfoldLines",
    "emacs-mcx.backwardWord": "editor::MoveToPreviousWordStart",
    "emacs-mcx.cancel": "editor::Cancel",
    "emacs-mcx.deleteBackwardChar": "editor::Backspace",
    "emacs-mcx.forwardWord": "editor::MoveToNextWordEnd",
    "emacs-mcx.isearchExit": "editor::Cancel",
    "emacs-mcx.paredit.pareditKill": "editor::KillRingCut",
    "emacs-mcx.scrollDownCommand": "editor::MovePageDown",
    "emacs-mcx.setMarkCommand": "editor::SetMark",
    "emacs-mcx.yank": "editor::Paste",
    "explorer.newFile": "project_panel::NewFile",
    "explorer.openToSide": "project_panel::Open",
    "filesExplorer.copy": "project_panel::Copy",
    "filesExplorer.cut": "project_panel::Cut",
    "filesExplorer.paste": "project_panel::Paste",
    "github.copilot.chat.attachSelection": "agent::AddSelectionToThread",
    "gitlens.toggleFileBlame": "git::Blame",
    "go-to-next-change.go-to-next-scm-change": "editor::GoToNextChange",
    "go-to-next-change.go-to-previous-scm-change": "editor::GoToPreviousChange",
    "hideCodeActionWidget": "editor::Cancel",
    "hideSuggestWidget": "editor::Cancel",
    "history.showPrevious": "pane::GoBack",
    "inlineChat.arrowOutUp": "editor::Cancel",
    "interactive.input.clear": "editor::Cancel",
    "keybindings.editor.clearSearchResults": "editor::Cancel",
    "keybindings.editor.searchKeybindings": "zed::OpenKeymap",
    "leaveEditorMessage": "editor::Cancel",
    "leaveSnippet": "editor::Cancel",
    "list.collapse": "menu::SelectParent",
    "list.expand": "menu::SelectChild",
    "list.find": "search::FocusSearch",
    "list.focusDown": "menu::SelectNext",
    "list.focusPageDown": "menu::SelectLast",
    "list.focusPageUp": "menu::SelectFirst",
    "list.focusUp": "menu::SelectPrevious",
    "renameFile": "project_panel::Rename",
    "showPrevParameterHint": "editor::SignatureHelpPrevious",
    "testing.debugAtCursor": "debugger::Start",
    "testing.runAtCursor": "repl::Run",
    "welcome.goBack": "pane::GoBack",
    "welcome.showNewFileEntries": "workspace::NewFile",
    "workbench.action.chat.attachFile": "agent::OpenAddContextMenu",
    "workbench.action.chat.attachSelection": "agent::AddSelectionToThread",
    "workbench.action.chat.history": "agent::OpenHistory",
    "workbench.action.chat.openAgent": "agent::Chat",
    "workbench.action.chat.openInSidebar": "agent::Chat",
    "workbench.action.chat.switchToNextModel": "agent::CycleFavoriteModels",
    "workbench.action.closeActiveEditor": "pane::CloseActiveItem",
    "workbench.action.closeAllEditors": "pane::CloseAllItems",
    "workbench.action.closeEditorInAllGroups": "pane::CloseActiveItem",
    "workbench.action.closeEditorsAndGroup": "workspace::CloseAllItemsAndPanes",
    "workbench.action.closeEditorsInGroup": "pane::CloseAllItems",
    "workbench.action.closeQuickOpen": "menu::Cancel",
    "workbench.action.closeWindow": "workspace::CloseWindow",
    "workbench.action.debug.continue": "debugger::Continue",
    "workbench.action.debug.stepInto": "debugger::StepInto",
    "workbench.action.debug.stepOut": "debugger::StepOut",
    "workbench.action.debug.stepOver": "debugger::StepOver",
    "workbench.action.files.newUntitledFile": "workspace::NewFile",
    "workbench.action.files.save": "workspace::Save",
    "workbench.action.findInFiles": "pane::DeploySearch",
    "workbench.action.focusActiveEditorGroup": "pane::ActivateItem",
    "workbench.action.hideComment": "editor::Cancel",
    "workbench.action.hideInterfaceOverview": "editor::Cancel",
    "workbench.action.lastEditorInGroup": "pane::ActivateLastItem",
    "workbench.action.navigateBack": "pane::GoBack",
    "workbench.action.newWindow": "workspace::NewWindow",
    "workbench.action.nextEditor": "pane::ActivateNextItem",
    "workbench.action.nextEditorInGroup": "pane::ActivateNextItem",
    "workbench.action.openGlobalKeybindings": "zed::OpenKeymap",
    "workbench.action.openRecent": "projects::OpenRecent",
    "workbench.action.quickOpen": "file_finder::Toggle",
    "workbench.action.quickOpenNavigateNextInFilePicker": "menu::SelectNext",
    "workbench.action.quickOpenNavigateNextInViewPicker": "menu::SelectNext",
    "workbench.action.quickOpenView": "file_finder::Toggle",
    "workbench.action.quit": "zed::Quit",
    "workbench.action.showAllEditorsByMostRecentlyUsed": "tab_switcher::Toggle",
    "workbench.action.showCommands": "command_palette::Toggle",
    "workbench.action.switchWindow": "workspace::SwitchProject",
    "workbench.action.terminal.focus": "terminal_panel::Toggle",
    "workbench.action.terminal.pasteSelection": "terminal::Paste",
    "workbench.action.togglePanel": "workspace::ToggleBottomDock",
    "workbench.action.toggleSidebarVisibility": "workspace::ToggleLeftDock",
    "workbench.action.zoomIn": "zed::IncreaseUiFontSize",
    "workbench.action.zoomOut": "zed::DecreaseUiFontSize",
    "workbench.banner.focusBanner": "editor::Cancel",
    "workbench.files.action.createFolderFromExplorer": "project_panel::NewDirectory",
    "workbench.statusBar.clearFocus": "editor::Cancel",
    "workbench.view.explorer": "project_panel::ToggleFocus",
    "settings.action.focusLevelUp": "editor::Cancel",
}
SPECIAL_RUN_COMMANDS_MAP: Dict[Tuple[str, ...], Any] = {
    ("actions.findWithSelection", "actions.find"): "buffer_search::Deploy",
    ("workbench.view.explorer", "workbench.files.action.focusFilesExplorer"): "project_panel::ToggleFocus",
}


@dataclass
class SkippedBinding:
    index: int
    key: str
    command: str
    reason: str


@dataclass
class Collision:
    context: str
    key: str
    previous: Any
    current: Any
    source_index: int


def get_default_vscode_keybindings_path() -> Optional[Path]:
    home = Path.home()
    system = platform.system()
    if system == "Windows":
        return home / "AppData/Roaming/Code/User/keybindings.json"
    if system == "Darwin":
        return home / "Library/Application Support/Code/User/keybindings.json"
    if system == "Linux":
        return home / ".config/Code/User/keybindings.json"
    return None


def normalize_keystroke(stroke: str) -> Optional[str]:
    stroke = stroke.strip()
    if not stroke:
        return None

    tokens = [token.strip().lower() for token in stroke.split("+")]
    if not tokens:
        return None

    key_token = tokens[-1]
    modifier_tokens = tokens[:-1]
    if key_token == "":
        key_token = "+"

    normalized_modifiers: List[str] = []
    for token in modifier_tokens:
        if not token:
            continue
        mapped = MODIFIER_ALIASES.get(token)
        if mapped is None:
            return None
        normalized_modifiers.append(mapped)

    seen = set()
    ordered_modifiers: List[str] = []
    for modifier in MODIFIER_ORDER:
        if modifier in normalized_modifiers and modifier not in seen:
            ordered_modifiers.append(modifier)
            seen.add(modifier)

    normalized_key = KEY_ALIASES.get(key_token, key_token)
    if normalized_key.startswith("[") and normalized_key.endswith("]") and len(normalized_key) > 2:
        bracket_token = normalized_key[1:-1].strip().lower()
        normalized_key = KEY_ALIASES.get(bracket_token, bracket_token)
    if not normalized_key:
        return None

    full = ordered_modifiers + [normalized_key]
    return "-".join(full)


def normalize_keybinding_key(key: str) -> Optional[str]:
    strokes = [stroke for stroke in key.strip().split() if stroke]
    if not strokes:
        return None

    normalized: List[str] = []
    for stroke in strokes:
        normalized_stroke = normalize_keystroke(stroke)
        if normalized_stroke is None:
            return None
        normalized.append(normalized_stroke)
    return " ".join(normalized)


def infer_context(when: Optional[str], command: str) -> str:
    when_text = (when or "").lower()
    base_command = command.lstrip("-")

    if (
        "terminalfocus" in when_text
        or base_command.startswith("workbench.action.terminal")
        or base_command.startswith("terminal.")
    ):
        return "Terminal"

    if (
        any(token in when_text for token in PROJECT_WHEN_TOKENS)
        or base_command.startswith("explorer.")
        or base_command.startswith("filesExplorer.")
        or base_command.startswith("workbench.files.action")
        or base_command == "renameFile"
    ):
        return "ProjectPanel && not_editing"

    if any(token in when_text for token in MENU_WHEN_TOKENS) or base_command.startswith("list."):
        return "menu"

    if (
        any(token in when_text for token in EDITOR_WHEN_TOKENS)
        or base_command.startswith("editor.")
        or base_command.startswith("actions.find")
        or base_command.startswith("delete")
        or base_command.startswith("cursor")
        or base_command.startswith("emacs-mcx.")
    ):
        return "Editor && mode == full"

    return "Workspace"


def map_run_commands(args: Any) -> Optional[Any]:
    if not isinstance(args, dict):
        return None
    commands = args.get("commands")
    if not isinstance(commands, list):
        return None
    normalized = tuple(str(command) for command in commands)
    return SPECIAL_RUN_COMMANDS_MAP.get(normalized)


def map_command(command: str, args: Any) -> Tuple[bool, Optional[Any], Optional[str]]:
    if not isinstance(command, str):
        return False, None, "command is not string"

    if command == "" or command.startswith("-"):
        return True, None, None

    if command == "runCommands":
        mapped = map_run_commands(args)
        if mapped is not None:
            return True, mapped, None
        return False, None, "runCommands args are not supported"

    if args is not None:
        return False, None, "command args are not supported"

    mapped = COMMAND_MAP.get(command)
    if mapped is None:
        return False, None, f"unsupported command: {command}"
    return True, mapped, None


def ordered_contexts(
    contexts: List[Optional[str]],
    preferred_context_order: List[Optional[str]],
) -> List[Optional[str]]:
    preferred = [
        None,
        "Workspace",
        "Editor && mode == full",
        "Terminal",
        "ProjectPanel && not_editing",
        "menu",
    ]
    ordered: List[Optional[str]] = []
    for context in preferred_context_order + preferred:
        if context in contexts and context not in ordered:
            ordered.append(context)
    for context in sorted(c for c in contexts if c is not None):
        if context not in ordered:
            ordered.append(context)
    return ordered


def build_output(
    grouped: Dict[Optional[str], Dict[str, Any]],
    preferred_context_order: List[Optional[str]],
) -> List[Dict[str, Any]]:
    output: List[Dict[str, Any]] = []
    for context in ordered_contexts(list(grouped.keys()), preferred_context_order):
        bindings = grouped[context]
        ordered_bindings = {key: bindings[key] for key in sorted(bindings.keys())}
        if context is None:
            output.append({"bindings": ordered_bindings})
        else:
            output.append({"context": context, "bindings": ordered_bindings})
    return output


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def load_grouped_keymap(path: Path) -> Tuple[Dict[Optional[str], Dict[str, Any]], List[Optional[str]]]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        raise ValueError(f"Expected list JSON in {path}")

    grouped: Dict[Optional[str], Dict[str, Any]] = defaultdict(dict)
    context_order: List[Optional[str]] = []
    for entry in raw:
        if not isinstance(entry, dict):
            continue
        bindings = entry.get("bindings")
        if not isinstance(bindings, dict):
            continue
        raw_context = entry.get("context")
        context: Optional[str] = raw_context if isinstance(raw_context, str) and raw_context else None
        if context not in context_order:
            context_order.append(context)
        for key, value in bindings.items():
            if isinstance(key, str) and key:
                grouped[context][key] = value
    return grouped, context_order


def merge_grouped(
    base: Dict[Optional[str], Dict[str, Any]],
    overlay: Dict[Optional[str], Dict[str, Any]],
) -> Dict[Optional[str], Dict[str, Any]]:
    merged: Dict[Optional[str], Dict[str, Any]] = {
        context: dict(bindings)
        for context, bindings in base.items()
    }
    for context, bindings in overlay.items():
        merged.setdefault(context, {})
        merged[context].update(bindings)
    return merged


def build_report(
    source: Path,
    final_output: Path,
    auto_output: Path,
    manual_overrides: Optional[Path],
    manual_loaded: bool,
    emacs_base: Optional[Path],
    total: int,
    mapped: int,
    unbound: int,
    skipped: List[SkippedBinding],
    collisions: List[Collision],
) -> str:
    lines: List[str] = [
        "# Zed Keymap Conversion Report",
        "",
        f"- Generated: `{datetime.now(timezone.utc).isoformat()}`",
        f"- Source: `{source}`",
        f"- Auto output: `{auto_output}`",
        f"- Final output: `{final_output}`",
        f"- Emacs base: `{emacs_base}`",
        f"- Manual overrides: `{manual_overrides}`",
        f"- Manual overrides loaded: `{manual_loaded}`",
        f"- Total bindings: `{total}`",
        f"- Converted bindings: `{mapped}`",
        f"- Unbound bindings: `{unbound}`",
        f"- Skipped bindings: `{len(skipped)}`",
        f"- Key collisions: `{len(collisions)}`",
        "",
    ]

    lines.append("## Skipped Bindings")
    lines.append("")
    if not skipped:
        lines.append("- None")
    else:
        for item in skipped:
            lines.append(
                f"- #{item.index}: key=`{item.key}` command=`{item.command}` reason=`{item.reason}`"
            )

    lines.append("")
    lines.append("## Key Collisions")
    lines.append("")
    if not collisions:
        lines.append("- None")
    else:
        for item in collisions:
            previous = json.dumps(item.previous, ensure_ascii=False)
            current = json.dumps(item.current, ensure_ascii=False)
            lines.append(
                f"- #{item.source_index}: context=`{item.context}` key=`{item.key}` previous=`{previous}` current=`{current}`"
            )
    lines.append("")
    return "\n".join(lines)


def convert(
    source: Path,
    final_output: Path,
    auto_output: Path,
    report: Path,
    emacs_base: Optional[Path],
    manual_overrides: Optional[Path],
) -> None:
    raw_bindings = json.loads(source.read_text(encoding="utf-8"))
    if not isinstance(raw_bindings, list):
        raise ValueError(f"Expected list JSON in {source}")

    auto_grouped: Dict[Optional[str], Dict[str, Any]] = defaultdict(dict)
    preferred_context_order: List[Optional[str]] = []
    if emacs_base is not None:
        base_grouped, preferred_context_order = load_grouped_keymap(emacs_base)
        for context, bindings in base_grouped.items():
            auto_grouped[context].update(bindings)

    skipped: List[SkippedBinding] = []
    collisions: List[Collision] = []
    mapped_count = 0
    unbound_count = 0

    missing = object()
    for index, binding in enumerate(raw_bindings, start=1):
        if not isinstance(binding, dict):
            skipped.append(
                SkippedBinding(
                    index=index,
                    key="",
                    command="",
                    reason="binding entry is not object",
                )
            )
            continue

        raw_key = binding.get("key", "")
        raw_command = binding.get("command", "")
        when = binding.get("when")
        args = binding.get("args")

        if not isinstance(raw_key, str) or not raw_key.strip():
            skipped.append(
                SkippedBinding(
                    index=index,
                    key=str(raw_key),
                    command=str(raw_command),
                    reason="missing key",
                )
            )
            continue

        normalized_key = normalize_keybinding_key(raw_key)
        if normalized_key is None:
            skipped.append(
                SkippedBinding(
                    index=index,
                    key=raw_key,
                    command=str(raw_command),
                    reason="unsupported key expression",
                )
            )
            continue

        if not isinstance(raw_command, str):
            skipped.append(
                SkippedBinding(
                    index=index,
                    key=raw_key,
                    command=str(raw_command),
                    reason="command is not string",
                )
            )
            continue

        context = infer_context(when if isinstance(when, str) else None, raw_command)
        ok, mapped, reason = map_command(raw_command, args)
        if not ok:
            skipped.append(
                SkippedBinding(
                    index=index,
                    key=raw_key,
                    command=raw_command,
                    reason=reason or "unknown conversion error",
                )
            )
            continue

        existing = auto_grouped[context].get(normalized_key, missing)
        if existing is not missing and existing != mapped:
            collisions.append(
                Collision(
                    context=context,
                    key=normalized_key,
                    previous=existing,
                    current=mapped,
                    source_index=index,
                )
            )

        auto_grouped[context][normalized_key] = mapped
        if mapped is None:
            unbound_count += 1
        else:
            mapped_count += 1

    auto_data = build_output(auto_grouped, preferred_context_order)
    write_json(auto_output, auto_data)

    manual_grouped: Dict[Optional[str], Dict[str, Any]] = {}
    manual_context_order: List[Optional[str]] = []
    manual_loaded = False
    if manual_overrides is not None and manual_overrides.exists():
        manual_grouped, manual_context_order = load_grouped_keymap(manual_overrides)
        manual_loaded = True

    final_grouped = merge_grouped(auto_grouped, manual_grouped)
    final_context_order = preferred_context_order.copy()
    for context in manual_context_order:
        if context not in final_context_order:
            final_context_order.append(context)

    final_data = build_output(final_grouped, final_context_order)
    write_json(final_output, final_data)

    report_text = build_report(
        source=source,
        final_output=final_output,
        auto_output=auto_output,
        manual_overrides=manual_overrides,
        manual_loaded=manual_loaded,
        emacs_base=emacs_base,
        total=len(raw_bindings),
        mapped=mapped_count,
        unbound=unbound_count,
        skipped=skipped,
        collisions=collisions,
    )
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(report_text, encoding="utf-8")

    print(f"Converted {mapped_count} bindings, unbound {unbound_count}, skipped {len(skipped)}")
    print(f"Wrote auto keymap: {auto_output}")
    print(f"Wrote final keymap: {final_output}")
    print(f"Wrote report: {report}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate Zed keymap from VSCode keybindings with optional automatic manual override merge"
    )
    parser.add_argument("--input", help="Path to VSCode keybindings.json")
    parser.add_argument(
        "--output",
        default=str(DEFAULT_OUTPUT),
        help=f"Path to final merged Zed keymap.json (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--auto-output",
        default=str(DEFAULT_AUTO_OUTPUT),
        help=f"Path to auto-generated Zed keymap.json (default: {DEFAULT_AUTO_OUTPUT})",
    )
    parser.add_argument(
        "--manual-overrides",
        default=str(DEFAULT_MANUAL_OVERRIDES),
        help=f"Path to manual override keymap JSON (default: {DEFAULT_MANUAL_OVERRIDES})",
    )
    parser.add_argument(
        "--report",
        default=str(DEFAULT_REPORT),
        help=f"Path to conversion report markdown (default: {DEFAULT_REPORT})",
    )
    parser.add_argument(
        "--emacs-base",
        default=str(DEFAULT_EMACS_BASE),
        help=f"Path to Emacs-compatible base keymap JSON (default: {DEFAULT_EMACS_BASE})",
    )
    parser.add_argument(
        "--no-emacs-base",
        action="store_true",
        help="Do not merge Emacs-compatible base keymap",
    )
    parser.add_argument(
        "--no-manual-overrides",
        action="store_true",
        help="Do not merge manual override keymap",
    )
    args = parser.parse_args()

    if args.input:
        source = Path(args.input).expanduser().resolve()
    else:
        default_source = get_default_vscode_keybindings_path()
        if default_source is None:
            raise RuntimeError("Unsupported platform for default VSCode keybindings path")
        source = default_source

    if not source.exists():
        raise FileNotFoundError(f"VSCode keybindings file not found: {source}")

    final_output = Path(args.output).expanduser().resolve()
    auto_output = Path(args.auto_output).expanduser().resolve()
    report = Path(args.report).expanduser().resolve()

    emacs_base: Optional[Path] = None
    if not args.no_emacs_base:
        emacs_base = Path(args.emacs_base).expanduser().resolve()
        if not emacs_base.exists():
            raise FileNotFoundError(f"Emacs base keymap file not found: {emacs_base}")

    manual_overrides: Optional[Path] = None
    if not args.no_manual_overrides:
        manual_overrides = Path(args.manual_overrides).expanduser().resolve()

    convert(
        source=source,
        final_output=final_output,
        auto_output=auto_output,
        report=report,
        emacs_base=emacs_base,
        manual_overrides=manual_overrides,
    )


if __name__ == "__main__":
    main()
