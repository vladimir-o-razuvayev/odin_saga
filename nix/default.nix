{
  pkgs,
  odin,
}:
pkgs.stdenv.mkDerivation rec {
  pname = "odin_saga";
  version = "0.1";
  src = ../.;

  nativeBuildInputs = [odin];

  buildPhase = ''
    odin build $src/src -show-timings -out:${pname} -microarch:native -no-bounds-check -no-type-assert -thread-count:16 -o:speed
    mkdir -p $out/bin
    mv ${pname} $out/bin/
  '';

  doCheck = true;

  checkPhase = ''
    odin test $src/src
  '';

  meta = {
    description = "Interactive fiction/story-game compiler in Odin";
    platforms = pkgs.lib.platforms.all;
  };
}
