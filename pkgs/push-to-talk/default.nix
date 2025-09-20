{ lib
, stdenvNoCC
, fetchFromGitHub
, makeWrapper
, python3
, python3Packages
, ffmpeg
, xclip
, wl-clipboard
, portaudio
, libsndfile
, kbd
, xdotool
, wtype
}:

# Package: push-to-talk (Python GUI app)
# Upstream: https://github.com/yixin0829/push-to-talk
# Notes:
# - Upstream uses uv for dependency management and does not expose a build backend.
# - We run it as a Python application by copying sources and wrapping a Python
#   interpreter environment with the required runtime dependencies.

let
  # Additional PyPI packages not in nixpkgs
  playsound3 = python3Packages.buildPythonPackage rec {
    pname = "playsound3";
    version = "3.2.6";

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-oDa1hsHiWSzvQutuBrKFFvapfy5xA0FkGG2n6cK4RVM=";
    };

    pyproject = true;
    # Upstream uses hatchling backend
    build-system = [ python3Packages.hatchling ];
    nativeBuildInputs = [ python3Packages.wheel ];
    doCheck = false;
    pythonImportsCheck = [ "playsound3" ];
    meta = with lib; {
      description = "Cross-platform, single function module with no dependencies for playing sounds (playsound3 fork)";
      homepage = "https://pypi.org/project/playsound3/";
      license = licenses.mit;
    };
  };

  psola = python3Packages.buildPythonPackage rec {
    pname = "psola";
    version = "0.0.1";

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-oJ7evA3BvK/xz9b6mLjylK4qBzLXG++oon8ssJQIHR8=";
    };

    pyproject = true;
    build-system = [ python3Packages.setuptools ];
    nativeBuildInputs = [ python3Packages.wheel ];
    doCheck = false;
    # psola imports numpy, soundfile, tqdm, parselmouth and optionally pypar
    propagatedBuildInputs = with python3Packages; [ numpy soundfile tqdm parselmouth ] ++ [ pypar ];
    pythonImportsCheck = [ "psola" ];
    meta = with lib; {
      description = "Pitch-synchronous overlap-add (PSOLA) utilities";
      homepage = "https://pypi.org/project/psola/";
      license = licenses.mit;
    };
  };

  pypar = python3Packages.buildPythonPackage rec {
    pname = "pypar";
    version = "0.0.6";

    src = python3Packages.fetchPypi {
      inherit pname version;
      sha256 = "sha256-5po8PpdEUa4pvwiJ+yK1uT/xcgnwNdvbYzc6ifSV6XE=";
    };

    pyproject = true;
    build-system = [ python3Packages.setuptools ];
    nativeBuildInputs = [ python3Packages.wheel ];
    propagatedBuildInputs = with python3Packages; [ numpy ];
    doCheck = false;
    pythonImportsCheck = [ "pypar" ];
    meta = with lib; {
      description = "Python phoneme alignment representation";
      homepage = "https://github.com/maxrmorrison/pypar";
      license = licenses.mit;
    };
  };

  # Patch 'keyboard' to allow non-root usage on Linux by removing the strict EUID check.
  # Note: you will still need permission to read /dev/input (e.g., add your user to 'input' group).
  keyboardPatched = python3Packages.keyboard.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      if [ -f keyboard/_nixkeyboard.py ]; then
        substituteInPlace keyboard/_nixkeyboard.py \
          --replace "raise PermissionError('You must be root to use this library on linux.')" "# patched out: allow non-root" \
          --replace 'raise PermissionError("You must be root to use this library on linux.")' "# patched out: allow non-root" || true
      fi
      if [ -f keyboard/_nixcommon.py ]; then
        substituteInPlace keyboard/_nixcommon.py \
          --replace "raise ImportError('You must be root to use this library on linux.')" "pass" \
          --replace 'raise ImportError("You must be root to use this library on linux.")' "pass" || true
      fi
    '';
  });

  # Python runtime with required packages
  pythonEnv = python3.withPackages (ps: with ps; [
    keyboardPatched
    loguru
    numpy
    openai
    pyaudio
    pyautogui
    pyperclip
    soundfile
    pydub
    tkinter
  ] ++ [ playsound3 psola ]);

  # Python paths for ensuring _tkinter is discoverable
  sp = python3.sitePackages; # e.g., lib/python3.12/site-packages
  libDyn = builtins.replaceStrings [ "site-packages" ] [ "lib-dynload" ] sp;
in

stdenvNoCC.mkDerivation rec {
  pname = "push-to-talk";
  version = "0.4.0";

  src = fetchFromGitHub {
    owner = "yixin0829";
    repo = "push-to-talk";
    rev = "v${version}";
    sha256 = "sha256-VCiNgEW8vmSGDSPg3xZGPEKVcRWTZfnsVn53DNRSkvk=";
  };

  # Patch: Tk 8.7+/9.0 では 'trace variable' が廃止され 'trace add variable' 系に変更。
  # 上流の tkinter.StringVar.trace("w", ...) 呼び出しを後方互換な try/except へ置換。
  postPatch = ''
    # Tk trace API change対応
    substituteInPlace src/config_gui.py \
      --replace 'self.glossary_search_var.trace("w", self._filter_glossary_list)' \
"try:
            self.glossary_search_var.trace_add(\"write\", lambda *_: self._filter_glossary_list())
        except Exception:
            self.glossary_search_var.trace(\"w\", self._filter_glossary_list)"

    # デフォルト設定: Push-to-Talk 無効、Toggle=F12
    substituteInPlace src/push_to_talk.py \
      --replace "hotkey: str = field(\n        default_factory=lambda: (\n            f\"{'cmd' if sys.platform == 'darwin' else 'ctrl'}+shift+space\"\n        )\n    )" "hotkey: str = \"\"" \
      --replace "toggle_hotkey: str = field(\n        default_factory=lambda: (\n            f\"{'cmd' if sys.platform == 'darwin' else 'ctrl'}+shift+^\"\n        )\n    )" "toggle_hotkey: str = \"f12\""

    # HotkeyService: hotkey が空/disabled の場合は登録しない
    substituteInPlace src/hotkey_service.py \
      --replace 'self.hotkey = hotkey or self._get_default_hotkey()' 'self.hotkey = None if hotkey in (None, "", "disabled", "none", "off") else hotkey' \
      --replace 'self._parse_hotkey_combination(self.hotkey, self.hotkey_keys)' '(self.hotkey and self._parse_hotkey_combination(self.hotkey, self.hotkey_keys))' \
      --replace 'self._parse_hotkey_combination(self.toggle_hotkey, self.toggle_hotkey_keys)' '(self.toggle_hotkey and self._parse_hotkey_combination(self.toggle_hotkey, self.toggle_hotkey_keys))' \
      --replace 'keyboard.add_hotkey(self.hotkey, self._on_hotkey_press)' '(self.hotkey and keyboard.add_hotkey(self.hotkey, self._on_hotkey_press))' \
      --replace 'keyboard.add_hotkey(self.toggle_hotkey, self._on_toggle_hotkey_press)' '(self.toggle_hotkey and keyboard.add_hotkey(self.toggle_hotkey, self._on_toggle_hotkey_press))'
  '';

  nativeBuildInputs = [ makeWrapper ];

  # Ensure native libs required by Python packages are available at runtime
  buildInputs = [ portaudio libsndfile ];

  installPhase = ''
    runHook preInstall

    # Install sources required at runtime
    install -dm 0755 "$out/share/${pname}"
    cp -r src "$out/share/${pname}/"
    cp main.py "$out/share/${pname}/"
    # Optional assets (icon, README)
    if [ -f icon.ico ]; then cp icon.ico "$out/share/${pname}/"; fi
    if [ -f README.md ]; then cp README.md "$out/share/${pname}/"; fi

    # Provide a sitecustomize.py to monkey-patch keyboard on Linux/Wayland consoles
    cat > "$out/share/${pname}/sitecustomize.py" <<'PY'
# Inject minimal keymap to avoid dumpkeys on non-VC consoles (Wayland/X11)
try:
    import keyboard._nixkeyboard as nk
    from collections import defaultdict
    import os, subprocess

    def _fallback_build_tables():
        try:
            # Initialize minimal maps only once
            if getattr(nk, 'to_name', None) and getattr(nk, 'from_name', None):
                if nk.to_name and nk.from_name:
                    return
        except Exception:
            pass
        nk.to_name = defaultdict(list)
        nk.from_name = defaultdict(list)

        def reg(scan, mods, name):
            try:
                if name not in nk.from_name:
                    nk.from_name[name] = []
                pair = (scan, tuple(sorted(mods)))
                if pair not in nk.to_name:
                    nk.to_name[pair] = []
                if name not in nk.to_name[pair]:
                    nk.to_name[pair].append(name)
                if pair not in nk.from_name[name]:
                    nk.from_name[name].append(pair)
            except Exception:
                pass

        # Common scan codes (Linux input-event):
        # left ctrl=29, right ctrl=97; left shift=42, right shift=54; space=57; F6=64; F12=88
        reg(29, (), 'ctrl'); reg(97, (), 'ctrl')
        reg(42, (), 'shift'); reg(54, (), 'shift')
        reg(57, (), 'space')
        reg(64, (), 'f6')
        reg(88, (), 'f12')

    # Disable root enforcement via ensure_root if present
    try:
        import keyboard._nixcommon as nc
        def _ensure_root_noop():
            return None
        nc.ensure_root = _ensure_root_noop
    except Exception:
        pass

    nk.build_tables = _fallback_build_tables
except Exception:
    # If anything fails, continue without patching
    pass

# Monkey-patch text insertion to use wayland/x11 tools instead of pyautogui
try:
    from src import text_inserter as TI
    import os, subprocess

    def _run(cmd, text=None):
        subprocess.run(cmd, input=(text if text is not None else None), text=True, check=True)

    def _insert_via_clipboard(self, text: str) -> bool:
        try:
            if os.getenv('WAYLAND_DISPLAY'):
                _run(['wl-copy'], text)
                # Paste via key chord using wtype (use Control_L for reliability)
                _run(['wtype', '-M', 'Control_L', '-P', 'v', '-m', 'Control_L'])
            else:
                _run(['xclip', '-selection', 'clipboard'], text)
                _run(['xdotool', 'key', '--clearmodifiers', 'ctrl+v'])
            return True
        except Exception:
            return False

    def _insert_via_sendkeys(self, text: str) -> bool:
        try:
            if os.getenv('WAYLAND_DISPLAY'):
                _run(['wtype', '--', text])
            else:
                _run(['xdotool', 'type', '--', text])
            return True
        except Exception:
            return False

    TI.TextInserter._insert_via_clipboard = _insert_via_clipboard
    TI.TextInserter._insert_via_sendkeys = _insert_via_sendkeys
except Exception:
    pass

# Default STT language to Japanese ('ja') unless explicitly provided
try:
    from src.transcription import Transcriber
    _orig_transcribe = Transcriber.transcribe_audio
    def _ja_transcribe(self, audio_file_path, language=None):
        if language is None:
            language = 'ja'
        return _orig_transcribe(self, audio_file_path, language=language)
    Transcriber.transcribe_audio = _ja_transcribe
except Exception:
    pass

# Add Language setting to GUI and persist in config
try:
    import tkinter as tk
    from tkinter import ttk
    import os
    from src import config_gui as CG
    from src.push_to_talk import PushToTalkConfig, PushToTalkApp

    # Ensure config has a language attribute by default
    _orig_cfg_init = PushToTalkConfig.__init__
    def _cfg_init_lang(self, *args, **kwargs):
        _orig_cfg_init(self, *args, **kwargs)
        if not hasattr(self, 'language'):
            self.language = 'ja'
    PushToTalkConfig.__init__ = _cfg_init_lang

    # Save/load should include 'language'
    _orig_save = PushToTalkConfig.save_to_file
    def _save_with_lang(self, filepath: str):
        import json, os
        from dataclasses import asdict
        # Resolve XDG config path: ~/.config/push-to-talk/push_to_talk_config.json
        xdg = os.getenv('XDG_CONFIG_HOME') or os.path.expanduser('~/.config')
        cfg_dir = os.path.join(xdg, 'push-to-talk')
        cfg_path = os.path.join(cfg_dir, 'push_to_talk_config.json')
        # If caller passed default filename or relative path, redirect to XDG path
        if not filepath or (filepath == 'push_to_talk_config.json') or (not os.path.isabs(filepath)):
            filepath = cfg_path
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        data = asdict(self)
        data['language'] = getattr(self, 'language', 'ja')
        # Never persist API keys to disk
        data.pop('openai_api_key', None)
        with open(filepath, 'w') as f:
            json.dump(data, f, indent=2)
    PushToTalkConfig.save_to_file = _save_with_lang

    @classmethod
    def _load_with_lang(cls, filepath: str):
        import json, os
        # Resolve default path under XDG config
        xdg = os.getenv('XDG_CONFIG_HOME') or os.path.expanduser('~/.config')
        cfg_dir = os.path.join(xdg, 'push-to-talk')
        cfg_path = os.path.join(cfg_dir, 'push_to_talk_config.json')
        # If caller passed default filename or relative path, use XDG
        if not filepath or (filepath == 'push_to_talk_config.json') or (not os.path.isabs(filepath)):
            filepath = cfg_path
        try:
            with open(filepath, 'r') as f:
                data = json.load(f)
            obj = cls(**{k:v for k,v in data.items() if k in {
                'openai_api_key','stt_model','refinement_model','sample_rate','chunk_size','channels',
                'hotkey','toggle_hotkey','insertion_method','insertion_delay','enable_text_refinement',
                'enable_logging','enable_audio_feedback','enable_audio_processing','debug_mode',
                'silence_threshold','min_silence_duration','speed_factor','custom_glossary'
            }})
            obj.language = data.get('language', 'ja')
            return obj
        except Exception as e:
            from loguru import logger
            logger.warning(f"Failed to load config (lang) from {filepath}: {e}")
            o = cls()
            o.language = 'ja'
            return o
    PushToTalkConfig.load_from_file = _load_with_lang

    # Inject language section just after API settings
    _orig_api = CG.ConfigurationGUI._create_api_section
    def _api_with_lang(self, parent):
        _orig_api(self, parent)
        # Language section
        frame = self._create_section_frame(parent, "Language")
        ttk.Label(frame, text="Transcription Language:").grid(row=0, column=0, sticky='w', pady=2)
        self.config_vars['language'] = tk.StringVar(value=getattr(self.config, 'language', 'ja'))
        lang_values = ['auto','ja','en','zh','ko','de','fr','es','it','pt','ru']
        ttk.Combobox(frame, textvariable=self.config_vars['language'], values=lang_values, state='readonly', width=20).grid(row=0, column=1, sticky='w', padx=(10,0), pady=2)
        ttk.Label(frame, text='Default: ja (日本語) | auto=自動判定').grid(row=0, column=2, sticky='w', padx=(5,0), pady=2)
        frame.columnconfigure(1, weight=1)

        # API Key hint section (security)
        hint = self._create_section_frame(parent, "API Key Hint / APIキーの設定")
        text = (
            "API keys are NOT saved to JSON.\n"
            "Set OPENAI_API_KEY via environment, or put it in\n"
            "~/.config/push-to-talk/push-to-talk.env (OPENAI_API_KEY=...).\n"
            "The systemd user service reads EnvironmentFile.\n\n"
            "APIキーは JSON に保存されません。環境変数 OPENAI_API_KEY を\n"
            "設定するか、~/.config/push-to-talk/push-to-talk.env に\n"
            "OPENAI_API_KEY=... を記述してください。systemd ユーザサービスは\n"
            "EnvironmentFile から読み込みます。"
        )
        ttk.Label(hint, text=text, justify='left').grid(row=0, column=0, sticky='w')
        # Environment detection status
        env_status = "\u2713 Detected OPENAI_API_KEY in environment" if os.getenv('OPENAI_API_KEY') else "(No OPENAI_API_KEY in environment)"
        ttk.Label(hint, text=env_status, foreground=('green' if os.getenv('OPENAI_API_KEY') else 'gray')).grid(row=1, column=0, sticky='w', pady=(6,0))
    CG.ConfigurationGUI._create_api_section = _api_with_lang

    # Ensure language is written into new config objects
    _orig_get_cfg = CG.ConfigurationGUI._get_config_from_gui
    def _get_cfg_with_lang(self):
        cfg = _orig_get_cfg(self)
        try:
            setattr(cfg, 'language', self.config_vars['language'].get() or 'auto')
        except Exception:
            setattr(cfg, 'language', 'ja')
        return cfg
    CG.ConfigurationGUI._get_config_from_gui = _get_cfg_with_lang

    # Make transcription use configured language automatically
    _orig_proc = PushToTalkApp._process_recorded_audio
    def _proc_with_lang(self):
        orig = self.transcriber.transcribe_audio
        def _trans(path, language=None):
            lang = getattr(self.config, 'language', None)
            return orig(path, language=(language or lang))
        self.transcriber.transcribe_audio = _trans
        try:
            return _orig_proc(self)
        finally:
            self.transcriber.transcribe_audio = orig
    PushToTalkApp._process_recorded_audio = _proc_with_lang
except Exception:
    pass

# Patch default config values: disable push-to-talk by default, toggle=F12
try:
    from src.push_to_talk import PushToTalkConfig
    _orig_init = PushToTalkConfig.__init__
    def _patched_init(self, *args, **kwargs):
        _orig_init(self, *args, **kwargs)
        # Set toggle to F6 if not explicitly provided
        if ('toggle_hotkey' not in kwargs) or (not getattr(self, 'toggle_hotkey', "")):
            self.toggle_hotkey = 'f6'
        # Disable push-to-talk by default (keep user-specified value if provided)
        if 'hotkey' not in kwargs:
            # only if empty/unspecified
            if not getattr(self, 'hotkey', ""):
                self.hotkey = ""
    PushToTalkConfig.__init__ = _patched_init
except Exception:
    pass

# In daemon mode, neutralize HotkeyService to avoid global grabs and parsing
try:
    import os as _os
    if _os.getenv('PTT_DAEMON') == '1':
        from src.hotkey_service import HotkeyService as _HS
        import threading as _th
        def _noop_init(self, hotkey=None, toggle_hotkey=None):
            self.hotkey = None
            self.toggle_hotkey = None
            self.is_running = True
            self.is_recording = False
            self.is_toggle_mode = False
            self.on_start_recording = None
            self.on_stop_recording = None
            self._lock = _th.Lock()
        _HS.__init__ = _noop_init
        _HS.start_service = lambda self: True
        _HS.stop_service = lambda self: None
        def _on_toggle(self):
            with self._lock:
                if not self.is_running:
                    return
                if self.is_recording:
                    if self.on_stop_recording:
                        self.is_recording = False
                        self.is_toggle_mode = False
                        self.on_stop_recording()
                else:
                    if self.on_start_recording:
                        self.is_recording = True
                        self.is_toggle_mode = True
                        self.on_start_recording()
        _HS._on_toggle_hotkey_press = _on_toggle
except Exception:
    pass
PY

    # Headless daemon entrypoint (no-GUI): load config and run
    cat > "$out/share/${pname}/daemon.py" <<'PY'
#!/usr/bin/env python3
from loguru import logger
import sys, signal, time
import os
try:
    from src.push_to_talk import PushToTalkConfig, PushToTalkApp
    # Load config (XDG path is handled in the overridden loader)
    cfg = PushToTalkConfig.load_from_file("push_to_talk_config.json")
    # By default, disable internal hotkeys in daemon mode to avoid sending keys to apps
    # In daemon mode, do not register any global hotkeys; rely on compositor binding
    try:
        cfg.hotkey = ""
        cfg.toggle_hotkey = ""
    except Exception:
        pass
    app = PushToTalkApp(cfg)

    # Optional: allow compositor-level toggle via SIGUSR1
    _last = {'t': 0.0}
    def _toggle(_sig, _frm):
        try:
            now = time.time()
            # Debounce rapid repeats from compositor key-repeat (ignore <300ms)
            if now - _last['t'] < 0.3:
                return
            _last['t'] = now
            if app.hotkey_service:
                # Mimic toggle hotkey press
                app.hotkey_service._on_toggle_hotkey_press()
        except Exception as e:
            logger.warning(f"Toggle via signal failed: {e}")
    try:
        signal.signal(signal.SIGUSR1, _toggle)
    except Exception:
        pass

    # PID file for external control helpers
    try:
        xdg = os.getenv('XDG_STATE_HOME') or os.path.expanduser('~/.local/state')
        pdir = os.path.join(xdg, 'push-to-talk')
        os.makedirs(pdir, exist_ok=True)
        with open(os.path.join(pdir, 'daemon.pid'), 'w') as f:
            f.write(str(os.getpid()))
    except Exception as e:
        logger.debug(f"Could not write pidfile: {e}")

    app.run()  # blocking
except Exception as e:
    logger.error(f"Daemon error: {e}")
    sys.exit(1)
PY

    # Create launcher
    install -dm 0755 "$out/bin"
    makeWrapper "${pythonEnv}/bin/python" "$out/bin/${pname}" \
      --add-flags "$out/share/${pname}/main.py" \
      --prefix PYTHONPATH : "$out/share/${pname}:${pythonEnv}/${sp}:${python3Packages.tkinter}/${sp}:${python3Packages.tkinter}/${libDyn}" \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg xclip wl-clipboard kbd xdotool wtype ]}"

    # Daemon launcher (no GUI)
    makeWrapper "${pythonEnv}/bin/python" "$out/bin/${pname}-daemon" \
      --add-flags "$out/share/${pname}/daemon.py" \
      --prefix PYTHONPATH : "$out/share/${pname}:${pythonEnv}/${sp}" \
      --prefix PATH : "${lib.makeBinPath [ ffmpeg xclip wl-clipboard kbd xdotool wtype ]}"

    # Toggle helper: send SIGUSR1 to the daemon via pidfile
    cat > "$out/bin/${pname}-toggle" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/push-to-talk"
PIDFILE="$STATE_DIR/daemon.pid"
if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE" 2>/dev/null || true)"
  if [[ -n "''${PID}" ]] && kill -0 "$PID" 2>/dev/null; then
    kill -USR1 "$PID"
    exit 0
  fi
fi
echo "push-to-talk daemon not running or pidfile missing" >&2
exit 1
SH
    chmod +x "$out/bin/${pname}-toggle"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Push-to-talk speech-to-text app with GUI, using OpenAI for transcription and refinement";
    homepage = "https://github.com/yixin0829/push-to-talk";
    license = licenses.mit;
    platforms = platforms.linux; # Linux packaging tested; macOS build can be added later
    mainProgram = pname;
  };
}
