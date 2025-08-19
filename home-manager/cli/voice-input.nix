{ pkgs, ... }: {
  # Voice input tools configuration
  home.packages = with pkgs; [
    # Whisper.cpp for high-quality speech recognition
    whisper-cpp

    # Audio processing tools
    sox
    ffmpeg

    # Optional: Alternative voice input tools
    # nerd-dictation  # Lightweight alternative
  ];

  # Create whisper models directory
  home.file.".local/share/whisper-models/.keep".text = "";

  # Voice input helper script
  home.file.".local/bin/voice-input" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      # Voice input script using whisper.cpp
      # Usage: voice-input [model-size]
      # Model sizes: tiny, base, small, medium, large
      
      MODEL_SIZE="''${1:-base}"
      MODEL_DIR="$HOME/.local/share/whisper-models"
      MODEL_FILE="$MODEL_DIR/ggml-$MODEL_SIZE.bin"
      TEMP_AUDIO="/tmp/voice_input_$$.wav"
      
      # Download model if not exists
      if [ ! -f "$MODEL_FILE" ]; then
        echo "Downloading whisper model: $MODEL_SIZE..."
        mkdir -p "$MODEL_DIR"
        whisper-cpp-download-ggml "$MODEL_SIZE" "$MODEL_DIR"
      fi
      
      # Record audio (press Ctrl+C to stop)
      echo "Recording... Press Ctrl+C to stop"
      sox -d -r 16000 -c 1 -b 16 "$TEMP_AUDIO"
      
      # Transcribe
      echo "Transcribing..."
      whisper-cpp -m "$MODEL_FILE" -f "$TEMP_AUDIO" -nt --no-timestamps 2>/dev/null | \
        grep -v "^whisper" | \
        tr -d '\n' | \
        xclip -selection clipboard
      
      echo "Text copied to clipboard!"
      
      # Cleanup
      rm -f "$TEMP_AUDIO"
    '';
  };

  # Alternative: Real-time voice input script
  home.file.".local/bin/voice-input-realtime" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      
      # Real-time voice input using whisper.cpp stream mode
      # Usage: voice-input-realtime [model-size]
      
      MODEL_SIZE="''${1:-tiny}"  # Use tiny for real-time
      MODEL_DIR="$HOME/.local/share/whisper-models"
      MODEL_FILE="$MODEL_DIR/ggml-$MODEL_SIZE.bin"
      
      # Download model if not exists
      if [ ! -f "$MODEL_FILE" ]; then
        echo "Downloading whisper model: $MODEL_SIZE..."
        mkdir -p "$MODEL_DIR"
        whisper-cpp-download-ggml "$MODEL_SIZE" "$MODEL_DIR"
      fi
      
      echo "Starting real-time transcription... Press Ctrl+C to stop"
      
      # Use whisper-cpp stream mode for real-time transcription
      rec -r 16000 -c 1 -b 16 -t wav - | \
        whisper-cpp-stream -m "$MODEL_FILE" --step 3000 --length 10000
    '';
  };

  # Add .local/bin to PATH
  home.sessionPath = [
    "$HOME/.local/bin"
  ];

  # Shell aliases for convenience
  programs.fish.shellAliases = {
    voice = "$HOME/.local/bin/voice-input";
    voice-rt = "$HOME/.local/bin/voice-input-realtime";
    voice-ja = "$HOME/.local/bin/voice-input base"; # Base model works well for Japanese
  };

  programs.bash.shellAliases = {
    voice = "$HOME/.local/bin/voice-input";
    voice-rt = "$HOME/.local/bin/voice-input-realtime";
    voice-ja = "$HOME/.local/bin/voice-input base";
  };
}
