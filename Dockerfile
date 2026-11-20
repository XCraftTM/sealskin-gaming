# Gaming desktop for SealSkin: KDE webtop with Steam, Wine, Bottles and Prism Launcher
# baked in, and a Flatpak setup that works inside a container.
#
# Why bake things in: SealSkin starts a fresh container for every session and only the
# home directory (/config) persists, so anything installed with apt at runtime is gone
# next time. Runtime installs should go to Flatpak (user scope, lands in /config).
ARG BASE_TAG=dev
FROM lscr.io/linuxserver/webtop:${BASE_TAG}

ENV TITLE="Gaming Desktop" \
    # Flatpak apps (system ones from the image, user ones from the persistent home) in the menu
    XDG_DATA_DIRS="/config/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share"

# Steam with its 32-bit libraries and the Selkies input interposers. The base image's own
# installer normally runs on first launch; running it here keeps Steam in the image.
RUN /steam.sh install && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Windows compatibility and gaming tools, Prism Launcher, Flatpak + Discover backend
RUN apt-get update && \
    # plasma-discover is listed so it is upgraded to match the Flatpak backend's version
    apt-get install -y --no-install-recommends \
      cabextract \
      flatpak \
      fonts-wine \
      gamemode \
      gamemode-daemon \
      gamescope \
      libgamemode0:i386 \
      libgamemodeauto0:i386 \
      mangohud \
      plasma-discover \
      plasma-discover-backend-flatpak \
      prismlauncher \
      protontricks \
      vkbasalt \
      vulkan-tools \
      wine \
      wine32:i386 \
      wine64 \
      winetricks && \
    # Flatpak's sandbox (bubblewrap) can't use unprivileged user namespaces in a container on
    # Ubuntu 24.04+ hosts (AppArmor restriction); setuid bwrap works in the privileged container
    # the SealSkin app entry asks for (see store/apps.yml). Users have passwordless sudo here anyway.
    chmod u+s /usr/bin/bwrap && \
    # Discover: Flatpak only. Its PackageKit (apt) backend would offer Ubuntu packages that
    # land in the throwaway container layer, which is what made installs "disappear".
    dpkg-divert --rename --divert /usr/lib/x86_64-linux-gnu/qt6/plugins/discover/packagekit-backend.so.disabled \
      /usr/lib/x86_64-linux-gnu/qt6/plugins/discover/packagekit-backend.so && \
    rm -rf /var/lib/apt/lists/* /var/tmp/* /tmp/*

# Bottles from Flathub, installed system-wide so it is part of the image. The system remote
# is then disabled, so Discover installs new apps into the user's (persistent) installation.
RUN flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
    flatpak install --system --noninteractive -y flathub com.usebottles.bottles && \
    flatpak remote-modify --system --disable flathub && \
    rm -rf /var/tmp/* /tmp/*

COPY root/ /
RUN update-desktop-database /usr/share/applications
