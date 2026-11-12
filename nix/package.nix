{
  lib,
  buildNpmPackage,
  importNpmLock,
  electron,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
}:

buildNpmPackage rec {
  pname = "learnharness";
  inherit ((lib.importJSON ../package.json)) version;

  src = ../.;

  # Fetch each dependency from package-lock.json, so there is no
  # npmDepsHash to bump whenever the lockfile changes.
  npmDeps = importNpmLock { npmRoot = src; };
  npmConfigHook = importNpmLock.npmConfigHook;

  nativeBuildInputs = [
    makeWrapper
    copyDesktopItems
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
    NEXT_TELEMETRY_DISABLED = 1;
  };

  # `npm run build` (next build) has produced .next/standalone; finish the
  # server payload the way the electron-builder release does.
  postBuild = ''
    node scripts/build-server.mjs
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "learnharness";
      desktopName = "LearnHarness";
      comment = "An agent harness for efficient learning";
      exec = "learnharness";
      icon = "learnharness";
      categories = [ "Education" ];
      startupWMClass = "learnharness";
    })
  ];

  installPhase = ''
    runHook preInstall

    # The Electron shell only needs its own code: electron/main.cjs requires
    # nothing from node_modules (electron-updater is only loaded in
    # packaged builds), and the server carries its own traced node_modules.
    app=$out/share/${pname}
    mkdir -p $app
    cp -r package.json electron $app/

    # Recreate electron-builder's Resources/ layout
    res=$app/resources
    mkdir -p $res/server
    cp -r .next/standalone $res/server/standalone
    cp electron/server-title-guard.cjs $res/server-title-guard.cjs

    # Stock electron's resourcesPath is read-only and has no server/; point at ours
    substituteInPlace $app/electron/main.cjs \
      --replace-fail 'process.resourcesPath' "\"$res\""

    makeWrapper ${lib.getExe electron} $out/bin/${pname} \
      --add-flags $app \
      --set NODE_ENV production

    install -Dm444 build/icon.png \
      $out/share/icons/hicolor/512x512/apps/learnharness.png

    runHook postInstall
  '';

  meta = {
    description = "An agent harness for efficient learning, taking you from your current understanding to your goal";
    homepage = "https://github.com/amosblomqvist/learnharness";
    license = lib.licenses.agpl3Only;
    mainProgram = "learnharness";
  };
}
