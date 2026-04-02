# Intermediate Docker image for jemacs-qt static builds.
# Bakes static Qt6 + QScintilla from source, plus all Chez Scheme
# dependencies (jerboa, gherkin, jsh, chez-pcre2, chez-scintilla,
# chez-qt) so that subsequent jemacs-qt builds only compile jemacs
# itself (~5-10 min instead of ~30 min).
#
# Build with:
#   make docker-deps
#
# Uses BuildKit --build-context to pull dependency sources without
# copying them into the project directory.

ARG ARCH=x86_64
FROM alpine:3.21

# ── Phase 1: Alpine build deps ──────────────────────────────────────────
RUN apk add --no-cache \
    su-exec \
    cmake samurai perl python3 linux-headers patchelf \
    libxcb-dev xcb-util-dev xcb-util-image-dev \
    xcb-util-keysyms-dev xcb-util-renderutil-dev \
    xcb-util-wm-dev xcb-util-cursor-dev \
    libx11-dev libxkbcommon-dev \
    fontconfig-dev freetype-dev harfbuzz-dev \
    libpng-dev zlib-dev mesa-dev \
    pcre2-dev \
    at-spi2-core-dev libdrm-dev \
    zlib-static libxcb-static \
    fontconfig-static freetype-static harfbuzz-static \
    libpng-static bzip2-static expat-static brotli-static \
    libx11-static graphite2-static libxkbcommon-static \
    ncurses-dev ncurses-static \
    util-linux-dev util-linux-static \
    libvterm-dev libvterm-static \
    gcc g++ binutils make git curl wget

# Build static libXau (no Alpine -static package available)
RUN apk add --no-cache libxau-dev && \
    cd /tmp && \
    wget -q https://xorg.freedesktop.org/releases/individual/lib/libXau-1.0.12.tar.xz && \
    tar xf libXau-1.0.12.tar.xz && \
    cd libXau-1.0.12 && \
    ./configure --prefix=/usr --enable-static --disable-shared && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/libXau-1.0.12*

# Build static libxcb-util (no Alpine -static package; needed by xcb-image)
RUN cd /tmp && \
    wget -q https://xcb.freedesktop.org/dist/xcb-util-0.4.1.tar.xz && \
    tar xf xcb-util-0.4.1.tar.xz && \
    cd xcb-util-0.4.1 && \
    ./configure --prefix=/usr --enable-static --disable-shared && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/xcb-util-0.4.1*

# ── Phase 2: Build Qt6 qtbase static ────────────────────────────────────
ARG QT6_VERSION=6.8.3
RUN wget -q https://download.qt.io/official_releases/qt/6.8/${QT6_VERSION}/submodules/qtbase-everywhere-src-${QT6_VERSION}.tar.xz && \
    tar xf qtbase-everywhere-src-${QT6_VERSION}.tar.xz && \
    rm qtbase-everywhere-src-${QT6_VERSION}.tar.xz && \
    cmake -S qtbase-everywhere-src-${QT6_VERSION} -B qt6-build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=/opt/qt6-static \
      -DBUILD_SHARED_LIBS=OFF \
      -DQT_BUILD_EXAMPLES=OFF \
      -DQT_BUILD_TESTS=OFF \
      -DQT_BUILD_BENCHMARKS=OFF \
      -DFEATURE_xcb=ON \
      -DFEATURE_sql=OFF \
      -DFEATURE_network=OFF \
      -DFEATURE_testlib=OFF \
      -DFEATURE_printsupport=ON \
      -DFEATURE_dbus=OFF \
      -DFEATURE_opengl=OFF \
      -DFEATURE_vulkan=OFF \
      -DFEATURE_glib=OFF \
      -DFEATURE_icu=OFF && \
    cmake --build qt6-build --parallel && \
    cmake --install qt6-build && \
    rm -rf qtbase-everywhere-src-${QT6_VERSION} qt6-build

# ── Phase 3: Build QScintilla static ────────────────────────────────────
ARG QSCI_VERSION=2.14.1
RUN wget -q https://www.riverbankcomputing.com/static/Downloads/QScintilla/${QSCI_VERSION}/QScintilla_src-${QSCI_VERSION}.tar.gz && \
    tar xf QScintilla_src-${QSCI_VERSION}.tar.gz && \
    rm QScintilla_src-${QSCI_VERSION}.tar.gz && \
    cd QScintilla_src-${QSCI_VERSION}/src && \
    /opt/qt6-static/bin/qmake CONFIG+=staticlib && \
    make -j$(nproc) && \
    make install && \
    cd / && rm -rf QScintilla_src-${QSCI_VERSION}

# ── Phase 4: Generate pkg-config files with full transitive deps ─────────
# Static Qt6 cmake doesn't generate .pc files.  We extract direct deps
# from .prl files, then add known transitive deps manually.
RUN mkdir -p /opt/qt6-static/lib/pkgconfig && \
    prl_libs() { \
      grep '^QMAKE_PRL_LIBS ' "$1" | \
        sed 's/^QMAKE_PRL_LIBS *= *//' | \
        tr ' ' '\n' | grep '^-l' | \
        grep -v '^-lQt6' | tr '\n' ' '; \
    } && \
    CORE_PRIVATE=$(prl_libs /opt/qt6-static/lib/libQt6Core.prl) && \
    GUI_PRL=$(prl_libs /opt/qt6-static/lib/libQt6Gui.prl) && \
    XCB_PRL=$(prl_libs /opt/qt6-static/plugins/platforms/libqxcb.prl) && \
    TRANSITIVE="-lgraphite2 -lbz2 -lbrotlidec -lbrotlicommon -lexpat -lXau -lXdmcp" && \
    GUI_PRIVATE="$GUI_PRL $TRANSITIVE" && \
    XCB_TRANSITIVE="-lxcb-util -lxcb -lXau -lXdmcp" && \
    XCB_PRIVATE="$XCB_PRL $TRANSITIVE $XCB_TRANSITIVE" && \
    echo "Core deps: $CORE_PRIVATE" && \
    echo "Gui deps: $GUI_PRIVATE" && \
    echo "XCB deps: $XCB_PRIVATE" && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      '' \
      'Name: Qt6Core' 'Description: Qt6 Core' 'Version: 6.8.3' \
      'Cflags: -I${includedir} -I${includedir}/QtCore' \
      "Libs: -L\${libdir} -lQt6Core" \
      "Libs.private: $CORE_PRIVATE" \
      > /opt/qt6-static/lib/pkgconfig/Qt6Core.pc && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      '' \
      'Name: Qt6Gui' 'Description: Qt6 Gui' 'Version: 6.8.3' \
      'Requires: Qt6Core' \
      'Cflags: -I${includedir} -I${includedir}/QtGui' \
      "Libs: -L\${libdir} -lQt6Gui" \
      "Libs.private: $GUI_PRIVATE" \
      > /opt/qt6-static/lib/pkgconfig/Qt6Gui.pc && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      '' \
      'Name: Qt6Widgets' 'Description: Qt6 Widgets' 'Version: 6.8.3' \
      'Requires: Qt6Gui' \
      'Cflags: -I${includedir} -I${includedir}/QtWidgets -I${includedir}/QtGui -I${includedir}/QtCore' \
      "Libs: -L\${libdir} -lQt6Widgets" \
      > /opt/qt6-static/lib/pkgconfig/Qt6Widgets.pc && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      '' \
      'Name: Qt6PrintSupport' 'Description: Qt6 PrintSupport' 'Version: 6.8.3' \
      'Requires: Qt6Widgets' \
      'Cflags: -I${includedir} -I${includedir}/QtPrintSupport' \
      "Libs: -L\${libdir} -lQt6PrintSupport" \
      > /opt/qt6-static/lib/pkgconfig/Qt6PrintSupport.pc && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      'plugindir=${prefix}/plugins' \
      '' \
      'Name: Qt6XcbPlugin' 'Description: Qt6 XCB platform plugin' 'Version: 6.8.3' \
      'Requires: Qt6Gui' \
      "Libs: -L\${libdir} -L\${plugindir}/platforms -lqxcb -lQt6XcbQpa" \
      "Libs.private: $XCB_PRIVATE" \
      > /opt/qt6-static/lib/pkgconfig/Qt6XcbPlugin.pc && \
    printf '%s\n' \
      'prefix=/opt/qt6-static' \
      'includedir=${prefix}/include' \
      'libdir=${prefix}/lib' \
      '' \
      'Name: QScintilla' 'Description: QScintilla for Qt6' 'Version: 2.14.1' \
      'Requires: Qt6Widgets Qt6PrintSupport' \
      'Cflags: -I${includedir} -I${includedir}/Qsci' \
      "Libs: -L\${libdir} -lqscintilla2_qt6" \
      > /opt/qt6-static/lib/pkgconfig/QScintilla.pc && \
    echo "Generated .pc files:" && ls /opt/qt6-static/lib/pkgconfig/

# ── Phase 5: Build Chez Scheme from source for musl ─────────────────────
# Build WITHOUT --static so libkernel.a retains full dlopen support.
# This is needed because jemacs embeds the program as a .so and loads it
# at runtime via Sscheme_script (which calls dlopen internally).
# musl's static libdl.a provides dlopen in the final static binary.
ARG CHEZ_TAG=main
ARG CHEZ_COMMIT=
RUN git clone --depth 100 --branch ${CHEZ_TAG} \
      https://github.com/cisco/ChezScheme /tmp/ChezScheme && \
    cd /tmp/ChezScheme && \
    if [ -n "${CHEZ_COMMIT}" ]; then \
      echo "Pinning Chez to commit ${CHEZ_COMMIT}"; \
      git checkout ${CHEZ_COMMIT}; \
    fi && \
    ./configure --threads --installprefix=/opt/chez && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/ChezScheme

# ── Phase 5.5: Build tree-sitter + grammars (static) ──────────────────
ARG TS_VERSION=0.24.7
RUN git clone --depth 1 --branch v${TS_VERSION} \
      https://github.com/tree-sitter/tree-sitter /tmp/tree-sitter && \
    cd /tmp/tree-sitter && \
    cc -c -O2 -Ilib/include lib/src/lib.c -o lib/src/lib.o && \
    mkdir -p /opt/tree-sitter-lib && \
    ar rcs /opt/tree-sitter-lib/libtree-sitter.a lib/src/lib.o && \
    mkdir -p /opt/tree-sitter-include/tree_sitter && \
    cp lib/include/tree_sitter/api.h /opt/tree-sitter-include/tree_sitter/ && \
    rm -rf /tmp/tree-sitter

# Build tree-sitter grammar static archives
RUN mkdir -p /opt/tree-sitter-grammars && \
    build_grammar() { \
      name=$1; repo=$2; tag=$3; subdir=${4:-.}; \
      git clone --depth 1 --branch "$tag" \
        "https://github.com/$repo" /tmp/ts-$name && \
      cd /tmp/ts-$name/$subdir && \
      SRC_DIR=src && \
      gcc -c -O2 -I/opt/tree-sitter-include -I$SRC_DIR \
        $SRC_DIR/parser.c -o parser.o && \
      if [ -f $SRC_DIR/scanner.c ]; then \
        gcc -c -O2 -I/opt/tree-sitter-include -I$SRC_DIR \
          $SRC_DIR/scanner.c -o scanner.o && \
        ar rcs /opt/tree-sitter-grammars/libtree-sitter-$name.a parser.o scanner.o; \
      else \
        ar rcs /opt/tree-sitter-grammars/libtree-sitter-$name.a parser.o; \
      fi && \
      cd / && rm -rf /tmp/ts-$name; \
    } && \
    build_grammar c          tree-sitter/tree-sitter-c          v0.23.5 && \
    build_grammar cpp        tree-sitter/tree-sitter-cpp        v0.23.4 && \
    build_grammar python     tree-sitter/tree-sitter-python     v0.23.6 && \
    build_grammar javascript tree-sitter/tree-sitter-javascript v0.23.1 && \
    build_grammar rust       tree-sitter/tree-sitter-rust       v0.23.3 && \
    build_grammar go         tree-sitter/tree-sitter-go         v0.23.4 && \
    build_grammar bash       tree-sitter/tree-sitter-bash       v0.23.3 && \
    build_grammar json       tree-sitter/tree-sitter-json       v0.24.8 && \
    build_grammar ruby       tree-sitter/tree-sitter-ruby       v0.23.1 && \
    build_grammar java       tree-sitter/tree-sitter-java       v0.23.5 && \
    build_grammar css        tree-sitter/tree-sitter-css        v0.23.2 && \
    build_grammar html       tree-sitter/tree-sitter-html       v0.23.2 && \
    build_grammar lua        tree-sitter-grammars/tree-sitter-lua v0.3.0 && \
    build_grammar scheme     6cdh/tree-sitter-scheme            main && \
    echo "Grammars built:" && ls /opt/tree-sitter-grammars/

# ── Phase 6: Gerbil/Chez dependencies ──────────────────────────────────
ENV PKG_CONFIG_PATH=/opt/qt6-static/lib/pkgconfig
ENV SCHEME=/opt/chez/bin/scheme

# Copy dependency sources from build contexts
COPY --from=jerboa-src . /deps/jerboa
COPY --from=gherkin-src . /deps/gherkin
COPY --from=jsh-src . /deps/jsh
COPY --from=pcre2-src . /deps/chez-pcre2
COPY --from=sci-src . /deps/chez-scintilla
COPY --from=qt-src . /deps/chez-qt
COPY --from=qtshim-src . /deps/gerbil-qt
# qt_chez_shim.c is maintained in vendor/ (not in chez-qt) — copy it in
COPY vendor/qt_chez_shim.c vendor/qt_shim.h /deps/chez-qt/

# Pre-compile all Chez library dependencies.
# These .so files are baked into the image so jemacs builds only
# need to compile jemacs-specific modules.
RUN /opt/chez/bin/scheme \
      --libdirs /deps/jerboa/lib:/deps/gherkin:/deps/jsh/src:/deps/chez-pcre2:/deps/chez-scintilla/src:/deps/chez-qt \
      --compile-imported-libraries \
      --script /dev/stdin <<'EOF'
#!chezscheme
(import
  (except (chezscheme) make-hash-table hash-table? iota 1+ 1-
          getenv path-extension path-absolute? thread?
          make-mutex mutex? mutex-name)
  (jerboa core)
  (jerboa runtime)
  (std sugar)
  (std format)
  (std sort)
  (std pregexp)
  (std foreign)
  (std misc list)
  (std misc thread)
  (std os path)
  (std os signal)
  (compat types)
  (compat gambit-compat)
  (runtime util)
  (runtime table)
  (runtime c3)
  (runtime mop)
  (compat gambit)
  (jsh ffi)
  (jsh static-compat)
  (chez-scintilla constants)
  (chez-qt ffi)
  (chez-qt qt))
(display "Chez deps pre-compiled OK\n")
EOF

# Build static pcre2 shim object
RUN PCRE2_CFLAGS=$(pkg-config --cflags libpcre2-8 2>/dev/null || echo "") && \
    gcc -c -O2 -o /deps/chez-pcre2/pcre2_shim.o \
        /deps/chez-pcre2/pcre2_shim.c $PCRE2_CFLAGS -Wall

# Build static jsh FFI shim object
RUN gcc -c -O2 -o /deps/jsh/jsh_ffi_shim.o /deps/jsh/ffi-shim.c -Wall

# Build static qt_chez_shim object
RUN QT_CFLAGS=$(pkg-config --cflags Qt6Widgets 2>/dev/null || \
        echo "-I/opt/qt6-static/include -I/opt/qt6-static/include/QtCore \
              -I/opt/qt6-static/include/QtGui -I/opt/qt6-static/include/QtWidgets") && \
    gcc -c -O2 -fPIC -o /deps/chez-qt/qt_chez_shim.o \
        /deps/chez-qt/qt_chez_shim.c \
        -I/deps/gerbil-qt/vendor $QT_CFLAGS -Wall

# Build static libqt_shim.a from qt_shim.cpp
# qt_static_plugins.o must be separate (NOT in archive) — it contains
# Q_IMPORT_PLUGIN static constructors that the linker drops from archives.
RUN QT_CFLAGS=$(pkg-config --cflags Qt6Widgets 2>/dev/null || \
        echo "-I/opt/qt6-static/include -I/opt/qt6-static/include/QtCore \
              -I/opt/qt6-static/include/QtGui -I/opt/qt6-static/include/QtWidgets") && \
    QSCI_FLAGS="-DQT_SCINTILLA_AVAILABLE \
        $(pkg-config --cflags QScintilla 2>/dev/null || \
          echo "-I/opt/qt6-static/include -I/opt/qt6-static/include/Qsci")" && \
    g++ -c -fPIC -std=c++17 \
        $QT_CFLAGS $QSCI_FLAGS \
        /deps/gerbil-qt/vendor/qt_shim.cpp \
        -o /deps/gerbil-qt/vendor/qt_shim_static.o && \
    ar rcs /deps/gerbil-qt/vendor/libqt_shim.a \
        /deps/gerbil-qt/vendor/qt_shim_static.o && \
    printf '#include <QtPlugin>\nQ_IMPORT_PLUGIN(QXcbIntegrationPlugin)\n' \
        > /deps/gerbil-qt/vendor/qt_static_plugins.cpp && \
    g++ -c -fPIC -std=c++17 $QT_CFLAGS \
        /deps/gerbil-qt/vendor/qt_static_plugins.cpp \
        -o /deps/gerbil-qt/vendor/qt_static_plugins.o

WORKDIR /src
