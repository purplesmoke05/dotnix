{ lib, pkgs, ... }:

let
  defaultWallpaperPool = "mixed";
  excludedWallpaperNames = [
    "kde-scarlettree"
    "kde-scarlettree-dark"
  ];

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
      source = pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath;
    }
    {
      name = "gnome-dark";
      package = pkgs.nixos-artwork.wallpapers.gnome-dark;
      source = pkgs.nixos-artwork.wallpapers.gnome-dark.gnomeFilePath;
    }
    {
      name = "dracula";
      package = pkgs.nixos-artwork.wallpapers.dracula;
      source = pkgs.nixos-artwork.wallpapers.dracula.gnomeFilePath;
    }
    {
      name = "nineish-solarized-dark";
      package = pkgs.nixos-artwork.wallpapers.nineish-solarized-dark;
      source = pkgs.nixos-artwork.wallpapers.nineish-solarized-dark.gnomeFilePath;
    }
  ];

  accentWallpapers = [
    {
      name = "gear";
      package = pkgs.nixos-artwork.wallpapers.gear;
      source = pkgs.nixos-artwork.wallpapers.gear.gnomeFilePath;
    }
    {
      name = "nineish";
      package = pkgs.nixos-artwork.wallpapers.nineish;
      source = pkgs.nixos-artwork.wallpapers.nineish.gnomeFilePath;
    }
  ];

  nixosReviewWallpaperNames = [
    "binary-black"
    "binary-blue"
    "binary-red"
    "binary-white"
    "catppuccin-frappe"
    "catppuccin-latte"
    "catppuccin-macchiato"
    "catppuccin-mocha"
    "dracula"
    "gear"
    "gnome-dark"
    "gradient-grey"
    "moonscape"
    "mosaic-blue"
    "nineish"
    "nineish-dark-gray"
    "nineish-solarized-dark"
    "nineish-solarized-light"
    "nineish-catppuccin-frappe-alt"
    "nineish-catppuccin-frappe"
    "nineish-catppuccin-latte-alt"
    "nineish-catppuccin-latte"
    "nineish-catppuccin-macchiato-alt"
    "nineish-catppuccin-macchiato"
    "nineish-catppuccin-mocha-alt"
    "nineish-catppuccin-mocha"
    "recursive"
    "simple-blue"
    "simple-dark-gray"
    "simple-dark-gray-bootloader"
    "simple-dark-gray-bottom"
    "simple-light-gray"
    "simple-red"
    "stripes-logo"
    "stripes"
    "waterfall"
    "watersplash"
  ];

  nixosReviewWallpapers = map
    (
      name:
      let
        package = pkgs.nixos-artwork.wallpapers.${name};
      in
      {
        inherit name package;
        source = package.gnomeFilePath;
      }
    )
    nixosReviewWallpaperNames;

  importedWallpaperPackages = [
    pkgs.gnome-backgrounds
    pkgs.kdePackages.plasma-workspace-wallpapers
    pkgs.pantheon.elementary-wallpapers
  ];

  reviewWallpaperPackages = [
    {
      name = "gnome-backgrounds";
      prefix = "gnome";
      roots = [ "${pkgs.gnome-backgrounds}/share/backgrounds/gnome" ];
    }
    {
      name = "elementary-wallpapers";
      prefix = "elementary";
      roots = [ "${pkgs.pantheon.elementary-wallpapers}/share/backgrounds" ];
    }
    {
      name = "mate-backgrounds";
      prefix = "mate";
      roots = [ "${pkgs.mate.mate-backgrounds}/share/backgrounds" ];
    }
    {
      name = "fedora-f32";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f32}/share/backgrounds" ];
    }
    {
      name = "fedora-f33";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f33}/share/backgrounds" ];
    }
    {
      name = "fedora-f34";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f34}/share/backgrounds" ];
    }
    {
      name = "fedora-f35";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f35}/share/backgrounds" ];
    }
    {
      name = "fedora-f36";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f36}/share/backgrounds" ];
    }
    {
      name = "fedora-f37";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f37}/share/backgrounds" ];
    }
    {
      name = "fedora-f38";
      prefix = "fedora";
      roots = [ "${pkgs.fedora-backgrounds.f38}/share/backgrounds" ];
    }
    {
      name = "lomiri-wallpapers";
      prefix = "lomiri";
      roots = [ "${pkgs.lomiri.lomiri-wallpapers}/share/wallpapers" ];
    }
    {
      name = "system76-wallpapers";
      prefix = "system76";
      roots = [
        "${pkgs.system76-wallpapers}/share/backgrounds"
        "${pkgs.system76-wallpapers}/share/wallpapers"
      ];
    }
    {
      name = "pop-wallpapers";
      prefix = "pop";
      roots = [
        "${pkgs.pop-wallpapers}/share/backgrounds"
        "${pkgs.pop-wallpapers}/share/wallpapers"
      ];
    }
    {
      name = "pop-hp-wallpapers";
      prefix = "pop-hp";
      roots = [
        "${pkgs.pop-hp-wallpapers}/share/backgrounds"
        "${pkgs.pop-hp-wallpapers}/share/wallpapers"
      ];
    }
    {
      name = "cosmic-wallpapers";
      prefix = "cosmic";
      roots = [
        "${pkgs.cosmic-wallpapers}/share/backgrounds"
        "${pkgs.cosmic-wallpapers}/share/wallpapers"
      ];
    }
    {
      name = "budgie-backgrounds";
      prefix = "budgie";
      roots = [
        "${pkgs.budgie-backgrounds}/share/backgrounds"
        "${pkgs.budgie-backgrounds}/share/wallpapers"
      ];
    }
    {
      name = "adapta-backgrounds";
      prefix = "adapta";
      roots = [
        "${pkgs.adapta-backgrounds}/share/backgrounds"
        "${pkgs.adapta-backgrounds}/share/wallpapers"
      ];
    }
    {
      name = "mint-artwork";
      prefix = "mint";
      roots = [ "${pkgs.mint-artwork}/share/backgrounds" ];
    }
  ];

  linkNixosArtwork = pool: item: ''
    link_file "${pool}" "${item.name}" "${item.source}"
  '';
in
{
  home.packages =
    map (item: item.package) (nixosDarkWallpapers ++ accentWallpapers)
    ++ importedWallpaperPackages;

  home.activation.linkWallpapers = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    wallpaperDir="$HOME/Pictures/Wallpapers"
    reviewDir="$wallpaperDir/review"
    mkdir -p "$wallpaperDir/dark" "$wallpaperDir/mixed" "$reviewDir"

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
      slug="$(slugify "$name")"

      [ -n "$ext" ] || return 0
      [ -n "$slug" ] || return 0

      case "$slug" in
        ${lib.concatMapStringsSep "\n        " (name: "\"${name}\") return 0 ;;") excludedWallpaperNames}
      esac

      ln -sf "$source" "$wallpaperDir/$pool/$slug.$ext"
    }

    link_review_file() {
      source_name="$1"
      name="$2"
      source="$3"
      ext="$(image_extension "$source")"
      slug="$(slugify "$name")"

      [ -n "$ext" ] || return 0
      [ -n "$slug" ] || return 0

      mkdir -p "$reviewDir/$source_name"
      ln -sf "$source" "$reviewDir/$source_name/$slug.$ext"
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

    link_review_tree() {
      source_name="$1"
      prefix="$2"
      root="$3"

      [ -d "$root" ] || return 0

      find "$root" -type f -print0 | while IFS= read -r -d $'\0' file; do
        is_image_file "$file" || continue

        rel="''${file#$root/}"
        rel_base="''${rel%.*}"
        link_review_file "$source_name" "$prefix-$rel_base" "$file"
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

    link_review_kde_wallpapers() {
      source_name="$1"
      package_root="$2"
      root="$package_root/share/wallpapers"

      [ -d "$root" ] || return 0

      for wallpaper in "$root"/*; do
        [ -d "$wallpaper/contents" ] || continue

        wallpaper_name="$(basename "$wallpaper")"
        light_image="$(pick_preferred_image "$wallpaper/contents/images" 2>/dev/null || true)"
        dark_image="$(pick_preferred_image "$wallpaper/contents/images_dark" 2>/dev/null || true)"

        if [ -n "$light_image" ]; then
          link_review_file "$source_name" "kde-$wallpaper_name" "$light_image"
        fi

        if [ -n "$dark_image" ]; then
          link_review_file "$source_name" "kde-$wallpaper_name-dark" "$dark_image"
        fi
      done
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

    ${lib.concatMapStrings (
      item: ''
        link_review_file "nixos-artwork" "${item.name}" "${item.source}"
      ''
    ) nixosReviewWallpapers}

    link_review_kde_wallpapers "plasma-workspace-wallpapers" "${pkgs.kdePackages.plasma-workspace-wallpapers}"

    ${lib.concatMapStrings (
      item:
      lib.concatMapStrings
        (root: ''
          link_review_tree "${item.name}" "${item.prefix}" "${root}"
        '')
        item.roots
    ) reviewWallpaperPackages}

    find "$reviewDir" -depth -type d -empty -delete
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
