{ lib
, buildNpmPackage
, fetchNpmDeps
}:

buildNpmPackage rec {
  pname = "ccmanager";
  version = "1.0.0"; # Replace with actual version

  # Create a minimal package.json for npm installation
  src = builtins.toFile "package.json" (builtins.toJSON {
    name = "ccmanager-wrapper";
    version = "1.0.0";
    dependencies = {
      ccmanager = version;
    };
  });

  # This hash will need to be updated after first build
  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    ln -s $out/lib/node_modules/.bin/ccmanager $out/bin/ccmanager
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "CC Manager tool";
    license = licenses.mit; # Update as needed
    maintainers = with maintainers; [ ];
    platforms = platforms.all;
  };
}