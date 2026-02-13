ARG APP="mudlet"

###############################################################################
# Stage 1: build
###############################################################################
FROM ubuntu:25.10 AS builder
ARG APP

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | debconf-set-selections \
 && apt-get install -y --no-install-recommends \
    ubuntu-restricted-extras build-essential git zlib1g-dev \
    libhunspell-dev libpcre2-dev libzip-dev libboost-dev libboost-all-dev \
    libyajl-dev libpulse-dev libpugixml-dev liblua5.1-0-dev lua-filesystem \
    lua-zip lua-sql-sqlite3 luarocks ccache lua5.1 libsecret-1-dev \
    libglu1-mesa-dev mesa-common-dev libglib2.0-dev libgstreamer1.0-dev \
    libqt5opengl5-dev cmake qt6-multimedia-dev libqt6core5compat6 \
    qt6-tools-dev qtkeychain-qt6-dev qt6-l10n-tools ninja-build \
    qt6-tools-dev-tools libqt6core5compat6-dev qttools5-dev qtmultimedia5-dev \
    qt6-speech-dev libzstd-dev libassimp-dev libcurl4-openssl-dev libssl-dev \
    openssl ca-certificates qt5ct libzzip-dev libsqlite3-dev \
    libdiscord-rpc-dev \
 && rm -rf /var/lib/apt/lists/*

RUN luarocks --lua-version 5.1 --tree=/usr install lcf \
 && luarocks --lua-version 5.1 --tree=/usr install luautf8 \
 && luarocks --lua-version 5.1 --tree=/usr install lua-yajl \
 && luarocks --lua-version 5.1 --tree=/usr install lrexlib-pcre2 \
 && luarocks --lua-version 5.1 --tree=/usr install luazip \
 && luarocks --lua-version 5.1 --tree=/usr install luasql-sqlite3

WORKDIR /build

ENV OWNER="Mudlet"
ENV REPO="Mudlet"
ENV VERSION="4.20.1"
ENV RELEASE_TAG="$REPO-$VERSION"
ENV REPO_URL="https://github.com/$OWNER/$REPO.git"

RUN git clone -j$(nproc) --recursive --single-branch -b "$RELEASE_TAG" "$REPO_URL" "$REPO" && \
  cd "$REPO" && \
  git checkout $RELEASE_TAG && \
  git submodule update --recursive

RUN mkdir -p /build/$REPO/build

WORKDIR /build/$REPO/build

RUN cmake .. -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DUSE_SANITIZER=""

RUN ninja "$APP"
RUN echo -n " " > ../src/app-build.txt
RUN ninja "$APP"

# Install into a clean prefix so we can copy it easily
RUN cmake --install . --prefix "/opt/$APP" && \
  cp -a "../translations/lua/" "/opt/$APP/share/$APP/lua/translations/"

###############################################################################
# Stage 2: runtime
###############################################################################
FROM ubuntu:25.10 AS zoomzoom
ARG APP

ENV DEBIAN_FRONTEND=noninteractive

# Runtime deps derived from: ldd /opt/mudlet/bin/mudlet
# Plus lua modules needed at runtime
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    lua5.1 lua-filesystem lua-zip lua-sql-sqlite3 \
    libassimp5 libcurl3t64-gnutls libdouble-conversion3 \
    libglib2.0-0t64 libglu1-mesa libgomp1 \
    libharfbuzz0b libhunspell-1.7-0 libicu76 \
    liblua5.1-0 libmd4c0 libminizip1t64 \
    libopengl0 libpcre2-16-0 libpng16-16t64 \
    libpugixml1v5 libpulse0 \
    libqt6core5compat6 libqt6core6t64 libqt6dbus6 \
    libqt6gui6 libqt6keychain1 libqt6multimedia6 \
    libqt6multimediawidgets6 libqt6network6 \
    libqt6opengl6 libqt6openglwidgets6 \
    libqt6texttospeech6 libqt6uitools6 libqt6widgets6 \
    libsndfile1 libxkbcommon0 libzip5 \
    libyajl2 libsqlite3-0 \
    libdiscord-rpc3 \
    ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Copy the built Mudlet installation and luarocks-installed modules
COPY --from=builder "/opt/$APP" "/usr"
COPY --from=builder "/usr/lib/lua/5.1" "/usr/lib/lua/5.1"
COPY --from=builder "/usr/share/lua/5.1" "/usr/share/lua/5.1"

RUN mkdir -p "/usr/local/share/$APP" && \
  ln -s "/usr/share/$APP/lua" "/usr/local/share/$APP/lua"
