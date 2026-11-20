# SealSkin Gaming Desktop

A KDE desktop for [SealSkin](https://docs.linuxserver.io/selkies/components/sealskin/), based on
`lscr.io/linuxserver/webtop` (Ubuntu), with gaming tools built in and a Flatpak setup that works
inside a container.

## What's included

- **Steam** (native, with 32-bit libraries and Proton support), already installed: no reinstall per session
- **Wine 10**, **Winetricks**, **Protontricks**: double-click a `.exe` / `.msi` to run it with Wine
- **Bottles** (Flatpak) for programs that need their own Wine prefix ("Open With" → Bottles)
- **Prism Launcher** for Minecraft (downloads the right Java itself)
- **GameMode** (`gamemoderun`), **MangoHud**, **vkBasalt**, **Gamescope**, `vulkaninfo`
- **Discover + Flathub**: apps install into your home folder, so they stay installed
- 64- and 32-bit Mesa (RADV Vulkan for AMD GPUs)

## Why things used to disappear

SealSkin starts a fresh container for every session; only your home folder persists.
Anything installed with `apt` lands in the throwaway container layer. This image bakes the tools
in; for anything else, install Flatpaks (Discover, or `flatpak install --user`), AppImages into your
home folder, or use `proot-apps`.

## Add it to SealSkin

1. In the SealSkin admin UI, add this store URL:
   `https://raw.githubusercontent.com/XCraftTM/sealskin-gaming/main/store/apps.yml`
2. Launch **Gaming Desktop (KDE)**, pick the AMD GPU, and use a persistent home.

### Permissions

Flatpak's sandbox (bubblewrap) can't run in a default container on Ubuntu 24.04+ hosts, where
AppArmor blocks unprivileged user namespaces. The image ships a setuid `bwrap`, and the app entry
runs the container **privileged**:

```yaml
docker_overrides:
  privileged: true
  shm_size: "1g"
```

Combined with the webtop's passwordless `sudo`, a privileged container means **whoever uses this
desktop can get root on the SealSkin host**. Only give this app to users you trust.

**Narrower alternative** (not tested): allow unprivileged user namespaces on the host with
`sysctl kernel.apparmor_restrict_unprivileged_userns=0` (persist it in `/etc/sysctl.d/`), and use
only `security_opt: ["seccomp=unconfined", "apparmor=unconfined"]` instead of `privileged`.
That loosens a host-wide hardening setting instead.

### What else the image fixes

- A **system D-Bus** service: Ubuntu's Flatpak checks parental controls over it before every
  install, so Discover and `flatpak install` failed without it.
- Discover is **Flatpak only** (its apt backend is disabled): apt installs never survived a session.
- `gamemoderun` is provided (Ubuntu only ships the daemon): use `gamemoderun %command%` in Steam.

## Build

GitHub Actions builds `ghcr.io/xcrafttm/sealskin-gaming:latest` on every push and weekly.
Locally: `docker build -t sealskin-gaming .` (base tag: `--build-arg BASE_TAG=ubuntu-kde`).
