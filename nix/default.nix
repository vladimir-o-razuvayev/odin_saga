{
  pkgs,
  odin,
}:
pkgs.stdenv.mkDerivation rec {
  pname = "saga";
  version = "0.1";
  src = ../.;

  nativeBuildInputs = [
    odin
    pkgs.zip
  ];

  buildPhase = ''
    odin build $src/src -show-timings -out:${pname} -microarch:native -no-bounds-check -no-type-assert -thread-count:16 -o:speed
    mkdir -p $out/bin
    mv ${pname} $out/bin/

    mkdir -p test_drive_package
    cp -R $src/examples/test_drive/assets test_drive_package/assets
    $out/bin/${pname} $src/examples/test_drive/main.saga test_drive_package/out.html
    (cd test_drive_package && zip -r $out/test_drive.zip out.html assets -x .DS_Store '*/.DS_Store')
  '';

  doCheck = true;

  checkPhase = ''
    odin test $src/src
  '';

  meta = {
    description = "Interactive fiction/story-game compiler";
    platforms = pkgs.lib.platforms.all;
  };
}
