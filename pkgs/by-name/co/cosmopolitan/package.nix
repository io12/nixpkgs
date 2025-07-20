{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,
  coreutils,
  replaceVars,
  unzip,
  buildPackages,
  fetchurl,
  fetchzip,
  parallel,
  tzdata,
  zip,
  flex,
  steam-run-free,
  wrapCCWith,
  wrapBintoolsWith,
}:

let

  bootstrap-tools = [
    "ar"
    "chmod"
    "cocmd"
    "compile"
    "cp"
    "echo"
    "fixupobj"
    "gzip"
    # "make"
    "mkdeps"
    "mkdir"
    "objbincopy"
    "package"
    "pecheck"
    "pwd"
    "rm"
    "rollup"
    "touch"
    "unbundle"
    "zipcopy"
    "zipobj"
  ];

  cosmoSrc =
    { rev, sha256 }:
    fetchFromGitHub {
      owner = "jart";
      repo = "cosmopolitan";
      inherit rev sha256;
      postFetch = ''
        # Remove vendored bootstrap binaries since we want to do a full bootstrap ourselves
        # TODO: usr/share/ssl
        # TODO: $out/usr/share/{dict,img,rom,terminfo,zoneinfo} \
        shopt -s globstar
        rm -rf \
          $out/build/bootstrap \
          $out/**/*.{gz,com,elf,aarch64,macho}
      '';
    };

  src-3-2 = cosmoSrc {
    rev = "3.2";
    sha256 = "sha256-Yxei5bPRhs3Qv6hDmAPnkFJ7u1XjbGgrXool9lpIWyk=";
  };

  archs = [
    "x86_64"
    "aarch64"
  ];

  crossBuildPkgs = {
    x86_64 = buildPackages.pkgsCross.musl64.buildPackages.pkgsStatic;
    aarch64 = buildPackages.pkgsCross.aarch64-multiplatform-musl.buildPackages.pkgsStatic;
  };

  binutils-2-35-2-unwrapped = lib.genAttrs archs (
    arch:
    crossBuildPkgs.${arch}.binutils-unwrapped.overrideAttrs {
      version = "2.35.2";
      src = fetchurl {
        url = "mirror://gnu/binutils/binutils-2.35.2.tar.gz";
        sha256 = "sha256-9IT2HIGqZ534TTWNmBjVvz5x/SJzA/I09yskQg2Y080=";
      };
      dontUpdateAutotoolsGnuConfigScripts = true;
      patches = [ ./patches/binutils/binutils-2.35.2.patch ];
      configurePlatforms = [ ];
      configureFlags = [
        "--disable-shared"
        "--disable-dependency-tracking"
        "--disable-silent-rules"
        "--disable-libstdcxx"
        "--disable-werror"
        "--disable-multilib"
        "--enable-deterministic-archives"
        "--disable-lto"
        "--with-system-zlib"
        "--with-static-standard-libraries"
        "--disable-libquadmath"
        "--disable-pgo-build"
        "--disable-libssp"
        "--disable-gprofng"
        "--disable-bootstrap"
        "--disable-libada"
        "--target=${arch}-linux-cosmo"
        "--program-prefix=${arch}-linux-cosmo-"
      ];
    }
  );

  binutils-2-42-unwrapped = lib.genAttrs archs (
    arch:
    crossBuildPkgs.${arch}.binutils-unwrapped.overrideAttrs {
      version = "2.42";
      src = fetchurl {
        url = "mirror://gnu/binutils/binutils-2.42.tar.gz";
        sha256 = "sha256-XSpsHUloalV4acquCLbC6DaZd179J1BeAbL02xoCT/w=";
      };
      dontUpdateAutotoolsGnuConfigScripts = true;
      patches = [ ./patches/binutils/binutils-2.42.patch ];
      configurePlatforms = [ ];
      configureFlags = [
        "--disable-shared"
        "--disable-dependency-tracking"
        "--disable-silent-rules"
        "--disable-libstdcxx"
        "--disable-werror"
        "--disable-multilib"
        "--enable-deterministic-archives"
        "--disable-lto"
        "--with-system-zlib"
        "--with-static-standard-libraries"
        "--disable-libquadmath"
        "--disable-pgo-build"
        "--disable-libssp"
        "--disable-gprofng"
        "--disable-bootstrap"
        "--disable-libada"
        "--target=${arch}-linux-cosmo"
        "--program-prefix=${arch}-linux-cosmo-"
      ];
    }
  );

  gcc-portcosmo-unwrapped = lib.genAttrs archs (
    arch:
    (crossBuildPkgs.${arch}.gcc14.cc.override {
      enableShared = false;
      enableLTO = false;
      enablePlugin = false;
      withoutTargetLibc = true;
      langFortran = false;
      langGo = false;
      langObjC = false;
      langObjCpp = false;
      langJit = false;
    }).overrideAttrs
      {
        version = "14.1.0";
        src = fetchFromGitHub {
          owner = "ahgamut";
          repo = "gcc";
          rev = "58ccca83f6ce7f33ee3bf1333a1e152a0a2486b7";
          sha256 = "sha256-XwsqHiNB9VqIZsCZd5kaTUB6dO7rmt+ef5aMCADUeKM=";
        };
        nativeBuildInputs = [
          flex
          binutils-2-42-unwrapped.${arch}
        ];
        dontUpdateAutotoolsGnuConfigScripts = true;
        patches = [ ];
        # src = fetchurl {
        #   url = "mirror://gnu/gcc/gcc-${gcc-version}/gcc-${gcc-version}.tar.xz";
        #   sha256 = "sha256-0I7cU2tUw3KhAQ/2YZ3SdMDxYDqkkhK6IPeqLNo2+os=";
        # };
        # patches = (oldAttrs.patches or [ ]) ++ [
        #   "${src}/third_party/gcc/portcosmo.patch"
        # ];
        postPatch = ''
          configureScripts=$(find . -name configure)
          for configureScript in $configureScripts; do
            patchShebangs $configureScript
          done

          substituteInPlace gcc/cp/portcosmo_bcref_cp.cc \
            --replace-fail '#include "stringpool.h"' '#include "stringpool.h"\n#include "c-family/initstruct.h"'
        '';
        CFLAGS = "-Os -D_LARGEFILE64_SOURCE=1 -DDONT_USE_BUILTIN_SETJMP=1";
        configurePlatforms = [ ];
        configureFlags = [
          "--without-headers"
          "--with-system-zlib"
          "--disable-shared"
          "--enable-static"
          "--disable-libquadmath"
          "--disable-decimal-float"
          "--disable-libitm"
          "--disable-fixed-point"
          "--disable-lto"
          "--with-static-standard-libraries"
          "--disable-libada"
          "--disable-libssp"
          "--disable-host-shared"
          "--enable-languages=c,c++"
          "--disable-objc-gc"
          "--disable-bootstrap"
          "--disable-assembly"
          "--disable-werror"
          "-enable-tls"
          "--enable-multilib"
          "--enable-multiarch"
          "--disable-libmudflap"
          "--disable-libsanitizer"
          "--disable-gnu-indirect-function"
          "--disable-libmpx"
          "--enable-initfini-array"
          "--disable-libstdcxx"
          "--without-libffi"
          "--without-libatomic"
          "--disable-gcov"
          "--enable-analyzer"
          "--disable-libvtv"
          "--disable-libgomp"
          "--disable-libatomic"
          "--disable-sjlj-exceptions"
          "--enable-gnu-indirect-function"
          "--with-gnu-as=yes"
          "--with-gnu-ld=yes"
          "--with-build-sysroot=/"
          "--with-as=${binutils-2-42-unwrapped.${arch}}/bin/${arch}-linux-cosmo-as"
          "--target=${arch}-linux-cosmo"
          "--program-prefix=${arch}-linux-cosmo-"
        ];
      }
  );

  gcc-portcosmo = lib.genAttrs archs (
    arch:
    wrapCCWith {
      cc = gcc-portcosmo-unwrapped.${arch};
      bintools = wrapBintoolsWith {
        bintools = binutils-2-42-unwrapped.${arch};
        libc = buildPackages.cosmopolitan;
      };
      libc = buildPackages.cosmopolitan;
      nixSupport.cc-cflags = [
      ];
    }
  );

  gcc-portcosmo-unwrapped-11-2 = lib.genAttrs archs (
    arch:
    (crossBuildPkgs.${arch}.gcc11.cc.override {
      enableShared = false;
      enableLTO = false;
      enablePlugin = false;
      langObjC = false;
      langObjCpp = false;
      withoutTargetLibc = true;
    }).overrideAttrs
      {
        version = "11.2.0";
        src = fetchFromGitHub {
          owner = "ahgamut";
          repo = "gcc";
          rev = "3b28e8f556f0a77d23e03039a783211c264de10f";
          sha256 = "sha256-Xk8pQ6+B3O6osyaVkWBmZpSyaBAUdI7O+YRamGwX++8=";
        };
        nativeBuildInputs = [
          flex
          binutils-2-42-unwrapped.${arch}
        ];
        dontUpdateAutotoolsGnuConfigScripts = true;
        patches = [ ];
        # src = fetchurl {
        #   url = "mirror://gnu/gcc/gcc-${gcc-version}/gcc-${gcc-version}.tar.xz";
        #   sha256 = "sha256-0I7cU2tUw3KhAQ/2YZ3SdMDxYDqkkhK6IPeqLNo2+os=";
        # };
        # patches = (oldAttrs.patches or [ ]) ++ [
        #   "${src}/third_party/gcc/portcosmo.patch"
        # ];
        postPatch = ''
          configureScripts=$(find . -name configure)
          for configureScript in $configureScripts; do
            patchShebangs $configureScript
          done
        '';
        CFLAGS = "-Os -D_LARGEFILE64_SOURCE=1 -DDONT_USE_BUILTIN_SETJMP=1";
        configurePlatforms = [ ];
        configureFlags = [
          "--without-headers"
          "--with-system-zlib"
          "--disable-shared"
          "--enable-static"
          "--disable-libquadmath"
          "--disable-decimal-float"
          "--disable-libitm"
          "--disable-fixed-point"
          "--disable-lto"
          "--with-static-standard-libraries"
          "--disable-libada"
          "--disable-libssp"
          "--disable-host-shared"
          "--enable-languages=c,c++"
          "--disable-objc-gc"
          "--disable-bootstrap"
          "--disable-assembly"
          "--disable-werror"
          "-enable-tls"
          "--disable-multilib"
          "--disable-multiarch"
          "--disable-libmudflap"
          "--disable-libsanitizer"
          "--disable-gnu-indirect-function"
          "--disable-libmpx"
          "--enable-initfini-array"
          "--disable-libstdcxx"
          "--without-libffi"
          "--without-libatomic"
          "--disable-gcov"
          "--disable-analyzer"
          "--disable-libvtv"
          "--disable-libgomp"
          "--disable-libatomic"
          "--disable-sjlj-exceptions"
          "--with-gnu-as=yes"
          "--with-gnu-ld=yes"
          "--with-build-sysroot=/"
          "--with-as=${binutils-2-42-unwrapped.${arch}}/bin/${arch}-linux-cosmo-as"
          "--target=${arch}-linux-cosmo"
          "--program-prefix=${arch}-linux-cosmo-"
        ];
      }
  );

  bootstrap-cflags = [
    "-D_COSMO_SOURCE"
    "-D__COSMOPOLITAN__"
    "-D__COSMOCC__"
    "-D__FATCOSMOCC__"
    "-DMODE='\"\"'"
    "-DADLER32_SIMD_SSSE3"
    "-DCRC32_SIMD_SSE42_PCLMUL"
    "-DDEFLATE_SLIDE_HASH_SSE2"
    "-DINFLATE_CHUNK_SIMD_SSE2"
    "-DINFLATE_CHUNK_READ_64LE"
    "-mpclmul -msse4.2 -mno-red-zone -mno-tls-direct-seg-refs"
    "-include libc/integral/normalize.inc"
    "-include libc/stdbool.h"
    "-fno-pie"
    "-nostdinc"
    "-fno-math-errno"
    "-iquote."
    "-isystem libc/isystem"
    "-fportcosmo"
    "-fno-dwarf2-cfi-asm"
    "-fno-unwind-tables"
    "-fno-asynchronous-unwind-tables"
    "-fno-semantic-interposition"
    "-fno-exceptions"
    "-static"
    "-nostdlib"
    "-no-pie"
    "-fuse-ld=bfd"
    "-Wl,-z,norelro"
    "-Wl,--gc-sections"
    "-fno-omit-frame-pointer"
    "-Wl,-T,ape.lds"
    "-Wl,-z,common-page-size=16384"
    "-Wl,-z,max-page-size=16384"
  ];

  bootstrap-3-2-prebuilt = fetchFromGitHub {
    owner = "jart";
    repo = "cosmopolitan";
    rev = "3.2";
    sha256 = "sha256-7wZwqFbR+pwIFYjCtfk5nshcHy49e58R/Vcmma8Ai/Q=";
    postFetch = ''
      mv $out/build/bootstrap .
      rm -rf $out
      mv bootstrap $out
    '';
  };

  bootstrap-3-2 = stdenv.mkDerivation {
    pname = "cosmopolitan-bootstrap";
    version = "3.2";
    src = src-3-2;

    strictDeps = true;

    # TODO: Try to make this a bit more arch-agnostic
    GCC = "${gcc-portcosmo-unwrapped-11-2.x86_64}/bin/x86_64-linux-cosmo-gcc";
    CFLAGS = bootstrap-cflags;

    nativeBuildInputs = [
      binutils-2-42-unwrapped.x86_64
      parallel
    ];

    buildPhase = ''
      mkdir -p $out

      # Fix weak linkage (why do I have to do this?)
      substituteInPlace libc/runtime/enable_tls.c --replace-fail _weaken ""

      # Preprocess linker script
      $GCC \
        -D__LINKER__ -D_COSMO_SOURCE -iquote. \
        -E -P -xc -o ape.lds \
        ape/ape.lds

      # Compile each libc source file
      cat ${./bootstrap-libc-sources.txt} | \
        parallel \
        -v -j $(nproc) --halt now,fail=1 \
        "$GCC $CFLAGS -g -c -o {#}.o {}"

      # Build static library
      find . -name '*.o' > objs.txt
      ar rcs cosmo.a @objs.txt

      # Compile bootstrap tools
      for tool in ${lib.concatStringsSep " " bootstrap-tools}; do
        $GCC $CFLAGS -g -o $out/$tool.com ./tool/build/$tool.c cosmo.a
      done
    '';

    dontConfigure = true;
    dontInstall = true;
    dontStrip = true;
    dontFixup = true;
  };

  cosmocc-3-2-prebuilt = fetchzip {
    url = "https://cosmo.zip/pub/cosmocc/cosmocc-3.2.zip";
    sha256 = "sha256-vTFPoFZkfbPXR2rzQfA69FnPJr0JMeItJiw3u8qCtao=";
    stripRoot = false;
  };

  cosmocc-3-2 = stdenv.mkDerivation {
    pname = "cosmocc";
    version = "3.2";
    src = src-3-2;

    nativeBuildInputs = [
      gcc-portcosmo-unwrapped-11-2.x86_64
      gcc-portcosmo-unwrapped-11-2.aarch64
      binutils-2-35-2-unwrapped.x86_64
      binutils-2-35-2-unwrapped.aarch64
      zip
    ];

    buildPhase = ''
      ln -s ${bootstrap-3-2} build/bootstrap

      # Stub binary blobs so compile succeeds
      : > ape/blink-linux-aarch64.gz
      : > ape/blink-xnu-aarch64.gz

      substituteInPlace ./tool/cosmocc/package.sh \
        --replace-fail 'ape ' "" \
        --replace-fail 'm=$AMD64' 'm=$AMD64 PREFIX=x86_64-linux-cosmo-' \
        --replace-fail 'm=$ARM64' 'm=$ARM64 PREFIX=aarch64-linux-cosmo-'

      mkdir -p cosmocc/{bin,libexec/gcc/{x86_64,aarch64}-linux-cosmo/11.2.0}
      cp \
        ${gcc-portcosmo-unwrapped-11-2.x86_64}/bin/* \
        ${gcc-portcosmo-unwrapped-11-2.aarch64}/bin/* \
        ${binutils-2-35-2-unwrapped.x86_64}/bin/* \
        ${binutils-2-35-2-unwrapped.aarch64}/bin/* \
        cosmocc/bin
      cp -Lr \
        ${gcc-portcosmo-unwrapped-11-2.x86_64}/libexec/gcc/x86_64-linux-cosmo/11.2.0/* \
        ${binutils-2-35-2-unwrapped.x86_64}/x86_64-linux-cosmo/bin/* \
        cosmocc/libexec/gcc/x86_64-linux-cosmo/11.2.0
      cp -Lr \
        ${gcc-portcosmo-unwrapped-11-2.aarch64}/libexec/gcc/aarch64-linux-cosmo/11.2.0/* \
        ${binutils-2-35-2-unwrapped.aarch64}/aarch64-linux-cosmo/bin/* \
        cosmocc/libexec/gcc/aarch64-linux-cosmo/11.2.0

      USE_SYSTEM_TOOLCHAIN=1 PREFIX=x86_64-linux-cosmo- \
        ./tool/cosmocc/package.sh
    '';

    installPhase = ''
      cp -r cosmocc $out
    '';

    dontConfigure = true;
    dontFixup = true;
  };

  cosmocc-3-2-3 = stdenv.mkDerivation {
    pname = "cosmocc";
    version = "3.2.3";

    src = cosmoSrc {
      rev = "3.2.3";
      sha256 = "sha256-6N67nfmEO5Hj1wU8TXDhb0nvDn8uedOF/jbGSKVbuOs=";
    };

    buildPhase = ''
      set -x

      cp -r ${bootstrap-3-2} build/bootstrap
      chmod 777 build/bootstrap
      for tool in mkdir compile; do
        ln -s $tool.com build/bootstrap/$tool
      done

      mkdir -p cosmocc
      cp -Lr ${cosmocc-3-2} cosmocc/3.2
      chmod 777 -R cosmocc
      for tool in mkdir echo rm; do
        echo '#!/usr/bin/env bash' >> cosmocc/3.2/bin/$tool.ape
        echo 'exec' $tool '$@' >> cosmocc/3.2/bin/$tool.ape
        chmod +x cosmocc/3.2/bin/$tool.ape
      done
      for tool in compile package ar; do
        cp build/bootstrap/$tool.com cosmocc/3.2/bin/$tool.ape
      done

      # Stub binary blobs so compile succeeds
      : > ape/blink-linux-aarch64.gz
      : > ape/blink-xnu-aarch64.gz

      substituteInPlace libc/nexgen32e/rdtscp.h \
        --replace-fail '0x7b' '(long)0x7b'

      substituteInPlace Makefile \
        --replace-fail 'build/bootstrap/cocmd.com' 'bash'

      substituteInPlace ./tool/cosmocc/package.sh \
        --replace-fail 'ape ' "" \
        --replace-fail 'm=$AMD64' 'm=$AMD64 PREFIX=x86_64-linux-cosmo-' \
        --replace-fail 'm=$ARM64' 'm=$ARM64 PREFIX=aarch64-linux-cosmo-'

      mkdir -p cosmocc/latest/{bin,libexec/gcc/{x86_64,aarch64}-linux-cosmo/11.2.0}
      cp \
        ${gcc-portcosmo-unwrapped-11-2.x86_64}/bin/* \
        ${gcc-portcosmo-unwrapped-11-2.aarch64}/bin/* \
        ${binutils-2-35-2-unwrapped.x86_64}/bin/* \
        ${binutils-2-35-2-unwrapped.aarch64}/bin/* \
        cosmocc/latest/bin
      cp -Lr \
        ${gcc-portcosmo-unwrapped-11-2.x86_64}/libexec/gcc/x86_64-linux-cosmo/11.2.0/* \
        ${binutils-2-35-2-unwrapped.x86_64}/x86_64-linux-cosmo/bin/* \
        cosmocc/latest/libexec/gcc/x86_64-linux-cosmo/11.2.0
      cp -Lr \
        ${gcc-portcosmo-unwrapped-11-2.aarch64}/libexec/gcc/aarch64-linux-cosmo/11.2.0/* \
        ${binutils-2-35-2-unwrapped.aarch64}/aarch64-linux-cosmo/bin/* \
        cosmocc/latest/libexec/gcc/aarch64-linux-cosmo/11.2.0

      USE_SYSTEM_TOOLCHAIN=1 PREFIX=x86_64-linux-cosmo- \
        ./tool/cosmocc/package.sh
    '';

    installPhase = ''
      cp -r cosmocc/latest $out
    '';

    dontConfigure = true;
    dontFixup = true;
  };

  cosmocc-unwrapped = stdenv.mkDerivation {
    pname = "cosmocc";
    version = "3.9.2";

    src = cosmoSrc {
      rev = "3.9.2";
      sha256 = "sha256-ZhujZtN6v0Mbkqu8fO9/AEqj8zubrbZ/tr1yKDl4rrE=";
    };

    BOOTSTRAP_CC = "${gcc-portcosmo-unwrapped.x86_64}/bin/x86_64-linux-cosmo-gcc";
    BOOTSTRAP_CFLAGS = bootstrap-cflags;

    nativeBuildInputs = [
      binutils-2-42-unwrapped.x86_64
      binutils-2-42-unwrapped.aarch64
      parallel
    ];

    buildPhase = ''
      set -x

      substituteInPlace Makefile \
        --replace-fail 'build/bootstrap/cocmd' 'bash'

      # Fake 3.8.0
      cosmocc=.cosmocc/3.8.0
      mkdir -p $cosmocc/{bin,libexec/gcc/{x86_64,aarch64}-linux-cosmo/14.1.0}
      $BOOTSTRAP_CC \
        -D__LINKER__ -D_COSMO_SOURCE -iquote. \
        -E -P -xc -o ape.lds \
        ape/ape.lds
      cat ${./bootstrap-libc-sources-3.9.2.txt} | \
        parallel \
        -v -j $(nproc) --halt now,fail=1 \
        "$BOOTSTRAP_CC $BOOTSTRAP_CFLAGS -g -c -o {#}.o {}"
      find . -name '*.o' > objs.txt
      ar rcs cosmo.a @objs.txt
      for tool in mkdir mkdeps package fixupobj objbincopy compile ar zipcopy echo rm; do
        $BOOTSTRAP_CC $BOOTSTRAP_CFLAGS \
          -DMODE=NULL \
          -DBUILD_SSE42 \
          -o $cosmocc/bin/$tool \
          tool/build/$tool.c \
          cosmo.a
        cp $cosmocc/bin/$tool{,.ape}
      done
      cp ${bootstrap-3-2}/zipobj.com $cosmocc/bin/zipobj
      cp \
        ${gcc-portcosmo-unwrapped.x86_64}/bin/* \
        ${gcc-portcosmo-unwrapped.aarch64}/bin/* \
        ${binutils-2-42-unwrapped.x86_64}/bin/* \
        ${binutils-2-42-unwrapped.aarch64}/bin/* \
        $cosmocc/bin
      cp -Lr \
        ${gcc-portcosmo-unwrapped.x86_64}/libexec/gcc/x86_64-linux-cosmo/14.1.0/* \
        ${binutils-2-42-unwrapped.x86_64}/x86_64-linux-cosmo/bin/* \
        $cosmocc/libexec/gcc/x86_64-linux-cosmo/14.1.0
      cp -Lr \
        ${gcc-portcosmo-unwrapped.aarch64}/libexec/gcc/aarch64-linux-cosmo/14.1.0/* \
        ${binutils-2-42-unwrapped.aarch64}/aarch64-linux-cosmo/bin/* \
        $cosmocc/libexec/gcc/aarch64-linux-cosmo/14.1.0

      substituteInPlace ./tool/cosmocc/package.sh \
        --replace-fail 'ape ' "" \
        --replace-fail 'm=$AMD64' 'm=$AMD64 PREFIX=x86_64-linux-cosmo-' \
        --replace-fail 'm=$ARM64' 'm=$ARM64 PREFIX=aarch64-linux-cosmo-'

      # No idea why I need this
      for mode in dbg optlinux tiny; do
        m=x86_64-$mode
        make -j m=$m o/$m/ape/{ape.{o,lds},ape-no-modify-self.o}
        m=aarch64-$mode
        make -j m=$m o/$m/ape/aarch64.lds
        for arch in x86_64 aarch64; do
          m=$arch-$mode
          make -j m=$m o/$m/libc/crt/crt.o
        done
      done

      cp -r $cosmocc cosmocc
      chmod 777 -R cosmocc
      rm -f cosmocc/bin/*.ape

      ./tool/cosmocc/package.sh

      # Some configure scripts need the compiler to end in "gcc,"
      # so make an alias
      for arch in x86_64 aarch64; do
        ln -s $arch-unknown-cosmo-cc cosmocc/bin/$arch-unknown-cosmo-gcc
      done
    '';

    installPhase = ''
      cp -r cosmocc $out
    '';

    dontConfigure = true;
    dontStrip = true;

    setupHook = ./setup-hook.sh;

    passthru = {
      isLLVM = false;
      isGNU = true;
      isClang = false;
      targetPrefix = "x86_64-unknown-cosmo-";
      bintools = cosmocc-unwrapped;
      libc = cosmocc-unwrapped;
      cc = cosmocc-unwrapped;
      inherit
        cosmocc-3-2
        cosmocc-3-2-prebuilt
        gcc-portcosmo
        gcc-portcosmo-unwrapped
        gcc-portcosmo-unwrapped-11-2
        binutils-2-42-unwrapped
        binutils-2-35-2-unwrapped
        bootstrap-3-2
        bootstrap-3-2-prebuilt
        ;
    };
  };

in
cosmocc-unwrapped
