# Gaming desktop for SealSkin: KDE webtop with Steam, Wine, Bottles and Prism Launcher
# baked in, and a Flatpak setup that works inside a container.
#
# Why bake things in: SealSkin starts a fresh container for every session and only the
# home directory (/config) persists, so anything installed with apt at runtime is gone
# next time. Runtime installs should go to Flatpak (user scope, lands in /config).
#
# Versions: Ubuntu freezes package versions per release, so gaming tools come from their
# upstream sources instead (WineHQ, kisak-mesa, GitHub releases, PyPI). The weekly CI
# rebuild then always picks up the latest stable releases.
ARG BASE_TAG=dev
FROM lscr.io/linuxserver/webtop:${BASE_TAG}

ENV TITLE="Gaming Desktop" \
    # Flatpak apps (system ones from the image, user ones from the persistent home) in the menu
    XDG_DATA_DIRS="/config/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

# Newer Mesa (AMD/Intel graphics drivers) from the kisak-mesa PPA, 64- and 32-bit. Added
# before Steam so its 32-bit graphics libraries come from here too.
RUN . /etc/os-release && \
    dpkg --add-architecture i386 && \
    mkdir -pm755 /etc/apt/keyrings && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xEB8B81E14DA65431D7504EA8F63F0F2B90935439" \
      | gpg --dearmor -o /etc/apt/keyrings/kisak-mesa.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/kisak-mesa.gpg] https://ppa.launchpadcontent.net/kisak/kisak-mesa/ubuntu ${VERSION_CODENAME} main" \
      > /etc/apt/sources.list.d/kisak-mesa.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      libgl1-mesa-dri \
      libglx-mesa0 \
      mesa-libgallium \
      mesa-va-drivers \
      mesa-vulkan-drivers && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Steam with its 32-bit libraries and the Selkies input interposers. The base image's own
# installer normally runs on first launch; running it here keeps Steam in the image.
RUN /steam.sh install && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Wine stable from WineHQ (installs to /opt/wine-stable, with wine on the PATH). The key is
# converted to binary: this apt ignores armored keys in a .key file ("unsupported filetype").
RUN . /etc/os-release && \
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq.gpg && \
    printf 'Types: deb\nURIs: https://dl.winehq.org/wine-builds/ubuntu\nSuites: %s\nComponents: main\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/winehq.gpg\n' \
      "${VERSION_CODENAME}" > /etc/apt/sources.list.d/winehq.sources && \
    apt-get update && \
    apt-get install -y --install-recommends winehq-stable && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Gaming tools and Flatpak + Discover backend from Ubuntu (these are current there)
RUN apt-get update && \
    # plasma-discover is listed so it is upgraded to match the Flatpak backend's version
    apt-get install -y --no-install-recommends \
      cabextract \
      flatpak \
      gamemode \
      gamemode-daemon \
      gamescope \
      libgamemode0:i386 \
      libgamemodeauto0:i386 \
      p7zip-full \
      plasma-discover \
      plasma-discover-backend-flatpak \
      python3-venv \
      unzip \
      vkbasalt \
      vulkan-tools \
      zenity && \
    # Flatpak's sandbox (bubblewrap) can't use unprivileged user namespaces in a container on
    # Ubuntu 24.04+ hosts (AppArmor restriction); setuid bwrap works in the privileged container
    # the SealSkin app entry asks for (see store/apps.yml). Users have passwordless sudo here anyway.
    chmod u+s /usr/bin/bwrap && \
    # Discover: Flatpak only. Its PackageKit (apt) backend would offer Ubuntu packages that
    # land in the throwaway container layer, which is what made installs "disappear".
    dpkg-divert --rename --divert /usr/lib/x86_64-linux-gnu/qt6/plugins/discover/packagekit-backend.so.disabled \
      /usr/lib/x86_64-linux-gnu/qt6/plugins/discover/packagekit-backend.so && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Latest stable releases straight from upstream
RUN set -e && \
    latest() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"; } && \
    asset() { curl -fsSL "https://api.github.com/repos/$1/releases/latest" | python3 -c "import sys,json,re; print(next(a['browser_download_url'] for a in json.load(sys.stdin)['assets'] if re.fullmatch(sys.argv[1], a['name'])))" "$2"; } && \
    cd /tmp && \
    # Prism Launcher (official AppImage, unpacked so it needs no FUSE). Keeps the same data
    # folder (~/.local/share/PrismLauncher) as the distro package did.
    curl -fsSL -o prism.AppImage "$(asset PrismLauncher/PrismLauncher 'PrismLauncher-Linux-x86_64\.AppImage')" && \
    chmod +x prism.AppImage && ./prism.AppImage --appimage-extract >/dev/null && \
    mv squashfs-root /opt/prismlauncher && \
    printf '#!/bin/sh\nexec /opt/prismlauncher/AppRun "$@"\n' > /usr/local/bin/prismlauncher && \
    chmod 755 /usr/local/bin/prismlauncher /opt/prismlauncher && \
    sed -e 's#^Exec=.*#Exec=prismlauncher %U#' -e 's#^TryExec=.*##' \
      /opt/prismlauncher/org.prismlauncher.PrismLauncher.desktop \
      > /usr/share/applications/org.prismlauncher.PrismLauncher.desktop && \
    install -Dm644 /opt/prismlauncher/org.prismlauncher.PrismLauncher.png \
      /usr/share/icons/hicolor/256x256/apps/org.prismlauncher.PrismLauncher.png && \
    # Winetricks (single script)
    curl -fsSL -o /usr/local/bin/winetricks \
      "https://raw.githubusercontent.com/Winetricks/winetricks/$(latest Winetricks/winetricks)/src/winetricks" && \
    chmod 755 /usr/local/bin/winetricks && \
    # Protontricks from PyPI, in its own environment
    python3 -m venv /opt/protontricks && \
    /opt/protontricks/bin/pip install --no-cache-dir protontricks && \
    ln -s /opt/protontricks/bin/protontricks /opt/protontricks/bin/protontricks-launch /usr/local/bin/ && \
    # MangoHud (release bundle with 64- and 32-bit libraries and its Vulkan layer)
    curl -fsSL -o mangohud.tar.gz "$(asset flightlessmango/MangoHud 'MangoHud-.*\.tar\.gz')" && \
    tar xf mangohud.tar.gz && \
    tar xf MangoHud/MangoHud-package.tar -C / && \
    rm -rf /var/tmp/* /tmp/*

# Bottles from Flathub, installed system-wide so it is part of the image. The system remote
# is then disabled, so Discover installs new apps into the user's (persistent) installation.
RUN flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
    flatpak install --system --noninteractive -y flathub com.usebottles.bottles && \
    flatpak remote-modify --system --disable flathub && \
    rm -rf /var/tmp/* /tmp/*

COPY root/ /
RUN update-desktop-database /usr/share/applications
