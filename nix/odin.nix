{
  lib,
  llvmPackages,
  fetchFromGitHub,
  makeBinaryWrapper,
  which,
  nix-update-script,
}: let
  bin_path = lib.makeBinPath (
    with llvmPackages; [
      bintools
      llvm
      clang
      lld
    ]
  );

  version = "dev-2025-06";
in
  llvmPackages.stdenv.mkDerivation {
    pname = "odin";
    inherit version;

    src = fetchFromGitHub {
      owner = "odin-lang";
      repo = "Odin";
      tag = version;
      hash = "sha256-Dhy62+ccIjXUL/lK8IQ+vvGEsTrd153tPp4WIdl3rh4=";
    };

    patches = [./darwin-remove-impure-links.patch];

    postPatch = ''
      patchShebangs --build build_odin.sh
    '';

    LLVM_CONFIG = lib.getExe' llvmPackages.llvm.dev "llvm-config";

    dontConfigure = true;

    buildFlags = ["release"];

    nativeBuildInputs = [
      makeBinaryWrapper
      which
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/bin
      cp odin $out/bin/odin

      mkdir -p $out/share
      cp -r {base,core,vendor,shared} $out/share

      wrapProgram $out/bin/odin --prefix PATH : ${bin_path} --set-default ODIN_ROOT $out/share

      make -C "$out/share/vendor/cgltf/src/"
      make -C "$out/share/vendor/stb/src/"
      make -C "$out/share/vendor/miniaudio/src/"

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script {};

    meta = {
      description = "Fast, concise, readable, pragmatic and open sourced programming language";
      downloadPage = "https://github.com/odin-lang/Odin";
      homepage = "https://odin-lang.org/";
      changelog = "https://github.com/odin-lang/Odin/releases/tag/${version}";
      license = lib.licenses.bsd3;
      mainProgram = "odin";
      platforms = lib.platforms.unix;
    };
  }
