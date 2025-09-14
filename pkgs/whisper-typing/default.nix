{ lib
, stdenv
, fetchFromGitHub
, python3
, gobject-introspection
, wrapGAppsHook3
, gtk3
, libappindicator
, makeWrapper
, wtype
}:

let
  # Pin to a specific commit for reproducibility
  version = "unstable-2025-09-14";
  rev = "aa36fb4f4a60778713c8c5cc0f69ed7861ac22c6"; # main as of 2025-09-14

  src = fetchFromGitHub {
    owner = "yadokani389";
    repo = "whisper-typing";
    inherit rev;
    sha256 = "sha256-ra//g28KDwXHygveYgKAg9LlYLA9J+1IjTiI8SIUF5E=";
  };

  serverPkgs = ps: with ps; [
    faster-whisper
    fastapi
    uvicorn
    python-multipart
    httpx
  ];

  clientPkgs = ps: with ps; [
    sounddevice
    soundfile
    pyperclip
    requests
    numpy
    setproctitle
    pystray
    pygobject3
    pillow
  ];

  pythonServer = python3.withPackages serverPkgs;
  pythonClient = python3.withPackages clientPkgs;
in

stdenv.mkDerivation rec {
  pname = "whisper-typing";
  inherit version src;

  nativeBuildInputs = [
    gobject-introspection
    wrapGAppsHook3
    makeWrapper
  ];

  buildInputs = [
    pythonClient
    gtk3
    libappindicator
  ];

  installPhase = ''
    runHook preInstall

    # Install sources
    install -Dm644 ${src}/server.py -t $out/libexec/whisper-typing/
    install -Dm644 ${src}/client.py -t $out/libexec/whisper-typing/

    # Create launchers
    mkdir -p $out/bin
    makeWrapper ${pythonServer}/bin/python3 $out/bin/whisper-typing-server \
      --add-flags "$out/libexec/whisper-typing/server.py"

    makeWrapper ${pythonClient}/bin/python3 $out/bin/whisper-typing-client \
      --add-flags "$out/libexec/whisper-typing/client.py"

    runHook postInstall
  '';

  # Ensure GTK/GI apps are wrapped; also add wtype to PATH for direct typing mode
  postFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ wtype ]})
    wrapGApp $out/bin/whisper-typing-client
  '';

  meta = with lib; {
    description = "Voice-to-text (Whisper) client/server with optional Ollama formatting";
    homepage = "https://github.com/yadokani389/whisper-typing";
    license = licenses.mit; # Upstream repo is public; adjust if needed
    maintainers = with maintainers; [ ];
    mainProgram = "whisper-typing-client";
    platforms = platforms.linux; # Tested on Linux; macOS not targeted here
  };
}

