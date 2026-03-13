{ lib, pkgs, ... }:

let
  defaultWallpaperPool = "dark";

  preferredKdeResolutions =
    [
      "5120x2880"
      "3840x2160"
      "3200x2000"
      "2560x1600"
      "1622x2880"
      "1440x2960"
      "1080x1920"
      "7680x2160"
      "720x1440"
    ];

  kdeResolutionCandidates = lib.concatMap
    (resolution: [
      "${resolution}.png"
      "${resolution}.jpg"
    ])
    preferredKdeResolutions;

  nixosDarkWallpapers = [
    {
      name = "binary-black";
      package = pkgs.nixos-artwork.wallpapers.binary-black;
    }
    {
      name = "gnome-dark";
      package = pkgs.nixos-artwork.wallpapers.gnome-dark;
    }
    {
      name = "dracula";
      package = pkgs.nixos-artwork.wallpapers.dracula;
    }
    {
      name = "nineish-solarized-dark";
      package = pkgs.nixos-artwork.wallpapers.nineish-solarized-dark;
    }
  ];

  accentWallpapers = [
    {
      name = "gear";
      package = pkgs.nixos-artwork.wallpapers.gear;
    }
    {
      name = "nineish";
      package = pkgs.nixos-artwork.wallpapers.nineish;
    }
  ];

  importedWallpaperPackages = [
    pkgs.gnome-backgrounds
    pkgs.kdePackages.plasma-workspace-wallpapers
    pkgs.pantheon.elementary-wallpapers
  ];

  linkNixosArtwork = pool: item: ''
    link_tree "${pool}" "${item.name}" "${item.package}"
  '';
in
{
  home.packages =
    map (item: item.package) (nixosDarkWallpapers ++ accentWallpapers)
    ++ importedWallpaperPackages;

  home.activation.linkWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wallpaperDir="$HOME/Pictures/Wallpapers"
    mkdir -p "$wallpaperDir/dark" "$wallpaperDir/mixed"

    find "$wallpaperDir" -type l -delete

    slugify() {
      printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//; s/-+/-/g'
    }

    image_extension() {
      printf '%s' "''${1##*.}" | tr '[:upper:]' '[:lower:]'
    }

    is_image_file() {
      case "$(image_extension "$1")" in
        png|jpg|jpeg|webp)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
    }

    link_file() {
      pool="$1"
      name="$2"
      source="$3"
      ext="$(image_extension "$source")"

      [ -n "$ext" ] || return 0

      ln -sf "$source" "$wallpaperDir/$pool/$(slugify "$name").$ext"
    }

    link_tree() {
      pool="$1"
      prefix="$2"
      root="$3"

      [ -d "$root" ] || return 0

      find "$root" -type f -print0 | while IFS= read -r -d $'\0' file; do
        is_image_file "$file" || continue

        rel="''${file#$root/}"
        rel_base="''${rel%.*}"
        link_file "$pool" "$prefix-$rel_base" "$file"
      done
    }

    pick_preferred_image() {
      dir="$1"

      for candidate in ${lib.concatStringsSep " " (map (candidate: "\"${candidate}\"") kdeResolutionCandidates)}; do
        if [ -f "$dir/$candidate" ]; then
          printf '%s\n' "$dir/$candidate"
          return 0
        fi
      done

      for file in "$dir"/*; do
        [ -f "$file" ] || continue
        if is_image_file "$file"; then
          printf '%s\n' "$file"
          return 0
        fi
      done

      return 1
    }

    link_gnome_wallpapers() {
      package_root="$1"
      root="$package_root/share/backgrounds/gnome"

      link_tree "mixed" "gnome" "$root"

      for file in "$root"/*; do
        [ -f "$file" ] || continue
        is_image_file "$file" || continue

        base="$(basename "$file")"
        case "$base" in
          *-d.*|*-dark.*)
            link_file "dark" "gnome-''${base%.*}" "$file"
            ;;
        esac
      done
    }

    link_elementary_wallpapers() {
      package_root="$1"
      root="$package_root/share/backgrounds"

      link_tree "mixed" "elementary" "$root"

      for file in "$root"/*; do
        [ -f "$file" ] || continue
        is_image_file "$file" || continue

        base="$(basename "$file")"
        case "$base" in
          *-dark.*)
            link_file "dark" "elementary-''${base%.*}" "$file"
            ;;
        esac
      done
    }

    link_kde_wallpapers() {
      package_root="$1"
      root="$package_root/share/wallpapers"

      [ -d "$root" ] || return 0

      for wallpaper in "$root"/*; do
        [ -d "$wallpaper/contents" ] || continue

        wallpaper_name="$(basename "$wallpaper")"
        light_image="$(pick_preferred_image "$wallpaper/contents/images" 2>/dev/null || true)"
        dark_image="$(pick_preferred_image "$wallpaper/contents/images_dark" 2>/dev/null || true)"

        if [ -n "$light_image" ]; then
          link_file "mixed" "kde-$wallpaper_name" "$light_image"
        elif [ -n "$dark_image" ]; then
          link_file "mixed" "kde-$wallpaper_name-dark" "$dark_image"
        fi

        if [ -n "$dark_image" ]; then
          link_file "dark" "kde-$wallpaper_name-dark" "$dark_image"
        fi
      done
    }

    ${lib.concatMapStrings (linkNixosArtwork "dark") nixosDarkWallpapers}
    ${lib.concatMapStrings (linkNixosArtwork "mixed") (nixosDarkWallpapers ++ accentWallpapers)}

    link_gnome_wallpapers "${pkgs.gnome-backgrounds}"
    link_kde_wallpapers "${pkgs.kdePackages.plasma-workspace-wallpapers}"
    link_elementary_wallpapers "${pkgs.pantheon.elementary-wallpapers}"
  '';

  services.wpaperd = {
    enable = true;
    settings = {
      default = {
        apply-shadow = false;
        path = "~/Pictures/Wallpapers/${defaultWallpaperPool}";
        sorting = "random";
        duration = "30m";
      };
    };
  };
}
