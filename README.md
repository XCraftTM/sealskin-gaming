# SealSkin Gaming Desktop

A KDE desktop for [SealSkin](https://docs.linuxserver.io/selkies/components/sealskin/), based on
`lscr.io/linuxserver/webtop` (Ubuntu), with gaming tools built in and a Flatpak setup that works
inside a container.

## What's included

- **Steam** (native, with 32-bit libraries and Proton support), already installed: no reinstall per session
- **Wine** stable from WineHQ, **Winetricks**, **Protontricks**: double-click a `.exe` / `.msi` to run it with Wine
- **Bottles** (Flatpak) for programs that need their own Wine prefix ("Open With" → Bottles)
- **Prism Launcher** for Minecraft (official AppImage; downloads the right Java itself)
- **GameMode** (`gamemoderun`), **MangoHud**, **vkBasalt**, **Gamescope**, `vulkaninfo`
- **Discover + Flathub**: apps install into your home folder, so they stay installed
- Newer 64- and 32-bit Mesa from the kisak-mesa PPA (RADV Vulkan for AMD GPUs)

### Staying up to date

Ubuntu freezes package versions per release, so the gaming tools come from their upstream
sources: Wine from WineHQ, Mesa from kisak-mesa, Prism Launcher, Winetricks and MangoHud from their
GitHub releases, Protontricks from PyPI, Bottles from Flathub. The weekly CI build (no cache)
picks up new stable releases automatically. Steam updates itself; Flatpaks you installed update
through Discover. Gamescope, GameMode and vkBasalt come from Ubuntu.

## Why things used to disappear

SealSkin starts a fresh container for every session; only your home folder persists.
Anything installed with `apt` lands in the throwaway container layer. This image bakes the tools
in; for anything else, install Flatpaks (Discover, or `flatpak install --user`), AppImages into your
home folder, or use `proot-apps`.

## Add it to SealSkin

1. In the SealSkin admin UI, add this store URL:
   `https://raw.githubusercontent.com/XCraftTM/sealskin-gaming/main/store/apps.yml`
2. Launch **Gaming Desktop (KDE)**, pick the AMD GPU, and use a persistent home.

### Permissions (admin step)

Flatpak's sandbox (bubblewrap) can't run in a default container on Ubuntu 24.04+ hosts, where
AppArmor blocks unprivileged user namespaces. The image ships a setuid `bwrap`, which works when the
container runs **privileged**. SealSkin ignores `privileged` in store entries (only an admin may
grant it), so set it yourself in the SealSkin admin UI:

- an **app template** with `DOCKER_PRIVILEGED` = `true`, used for this app, or
- an **admin override** `privileged: true` on the installed app.

Without it, Flatpak apps (Bottles, Discover installs) quit right after starting, and Flatpak warns
"Can't get document portal" (no `/dev/fuse`). Check a session with `ls /dev/fuse`.

Combined with the webtop's passwordless `sudo`, a privileged container means **whoever uses this
desktop can get root on the SealSkin host**. Only give this app to users you trust.

**Narrower alternative** (not tested): allow unprivileged user namespaces on the host with
`sysctl kernel.apparmor_restrict_unprivileged_userns=0` (persist it in `/etc/sysctl.d/`), and use
only `security_opt: ["seccomp=unconfined", "apparmor=unconfined"]` (allowed in store entries)
instead of `privileged`. That loosens a host-wide hardening setting instead, and Flatpak's
document portal still won't run (no `/dev/fuse`).

### What else the image fixes

- A **system D-Bus** service: Ubuntu's Flatpak checks parental controls over it before every
  install, so Discover and `flatpak install` failed without it.
- Discover is **Flatpak only** (its apt backend is disabled): apt installs never survived a session.
- `gamemoderun` is provided (Ubuntu only ships the daemon): use `gamemoderun %command%` in Steam.

## Keyboard layout

Set `KEYBOARD_LAYOUT` to your physical layout (XKB name: `de`, `us`, `fr`, `ch`, …); the store
entry sets `de`. Selkies ignores the browser's layout hint in this Wayland session, so without it
both Selkies and KDE use US English. Keys that need Shift there (like `+` on a German keyboard)
then reach X11 games such as Minecraft as Shift plus a substitute key, so they bind as "Left Shift".

Known Selkies limitations (not fixable in this image):

- Non-ASCII keys (ä, ö, ü, ß, …) still reach X11 games as Shift + a substitute key, even with the
  right layout. Typing them in text fields works.
- Keypad keys arrive as their main-keyboard equivalents (keypad `+` as `+`), because the web client
  sends characters rather than key positions.

## Build

GitHub Actions builds `ghcr.io/xcrafttm/sealskin-gaming:latest` on every push and weekly.
Locally: `docker build -t sealskin-gaming .` (base tag: `--build-arg BASE_TAG=ubuntu-kde`).
