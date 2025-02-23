{ lib, stdenv, fetchFromGitHub, cmake
, boost, python3, eigen, python3Packages
, icestorm, trellis
, llvmPackages

, enableGui ? false
, wrapQtAppsHook ? null
, qtbase ? null
, OpenGL ? null
}:

let
  boostPython = boost.override { python = python3; enablePython = true; };
in
stdenv.mkDerivation rec {
  pname = "nextpnr";
  version = "2021.09.27";

  srcs = [
    (fetchFromGitHub {
      owner  = "YosysHQ";
      repo   = "nextpnr";
      rev    = "9d8d3bdbc48133ff7758c9c5293e5904bc6e5ba7";
      sha256 = "sha256-5Axo8qX2+ATqQ170QqfhRwYfCRQLCKBW1kc89x9XljE=";
      name   = "nextpnr";
    })
    (fetchFromGitHub {
      owner  = "YosysHQ";
      repo   = "nextpnr-tests";
      rev    = "ccc61e5ec7cc04410462ec3196ad467354787afb";
      sha256 = "sha256-VT0JfpRLgfo2WG+eoMdE0scPM5nKZZ/v1XlkeDNcQCU=";
      name   = "nextpnr-tests";
    })
  ];

  sourceRoot = "nextpnr";

  nativeBuildInputs
     = [ cmake ]
    ++ (lib.optional enableGui wrapQtAppsHook);
  buildInputs
     = [ boostPython python3 eigen python3Packages.apycula ]
    ++ (lib.optional enableGui qtbase)
    ++ (lib.optional stdenv.cc.isClang llvmPackages.openmp);

  cmakeFlags =
    [ "-DCURRENT_GIT_VERSION=${lib.substring 0 7 (lib.elemAt srcs 0).rev}"
      "-DARCH=generic;ice40;ecp5;gowin"
      "-DBUILD_TESTS=ON"
      "-DICESTORM_INSTALL_PREFIX=${icestorm}"
      "-DTRELLIS_INSTALL_PREFIX=${trellis}"
      "-DTRELLIS_LIBDIR=${trellis}/lib/trellis"
      "-DGOWIN_BBA_EXECUTABLE=${python3Packages.apycula}/bin/gowin_bba"
      "-DUSE_OPENMP=ON"
      # warning: high RAM usage
      "-DSERIALIZE_CHIPDBS=OFF"
    ]
    ++ (lib.optional enableGui "-DBUILD_GUI=ON")
    ++ (lib.optional (enableGui && stdenv.isDarwin)
        "-DOPENGL_INCLUDE_DIR=${OpenGL}/Library/Frameworks");

  patchPhase = with builtins; ''
    # use PyPy for icestorm if enabled
    substituteInPlace ./ice40/CMakeLists.txt \
      --replace ''\'''${PYTHON_EXECUTABLE}' '${icestorm.pythonInterp}'
  '';

  preBuild = ''
    ln -s ../nextpnr-tests tests
  '';

  doCheck = true;

  postFixup = lib.optionalString enableGui ''
    wrapQtApp $out/bin/nextpnr-generic
    wrapQtApp $out/bin/nextpnr-ice40
    wrapQtApp $out/bin/nextpnr-ecp5
    wrapQtApp $out/bin/nextpnr-gowin
  '';

  meta = with lib; {
    description = "Place and route tool for FPGAs";
    homepage    = "https://github.com/yosyshq/nextpnr";
    license     = licenses.isc;
    platforms   = platforms.all;
    maintainers = with maintainers; [ thoughtpolice emily ];
  };
}
