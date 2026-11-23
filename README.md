# Lodestar

A customizable game launcher for Linux. It gathers your Steam, GOG and Epic games in one
library, with a store, news, your saves, and themes you make yourself.

## Install

Open a terminal and paste this line:

```
curl -fsSL https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.sh | sh
```

Then start **Lodestar** from your app menu, or type `lodestar`.

It installs for your user only and never asks for a password. The first install downloads
about 130 MB.

## Update and remove

| To do this | Type this |
|---|---|
| Get the newest version | `lodestar --update` |
| Remove Lodestar | `lodestar --uninstall` |

Removing Lodestar keeps your settings, themes, sign-ins and games.

## What you need

- Linux on a 64-bit PC (Intel/AMD, or ARM).
- `curl` or `wget`, and `unzip`. Most systems have them already.
- Steam, if you want your Steam games to show up. GOG and Epic sign-ins are inside the app.
- `python3`, only for starting Windows games from GOG and Epic.

## What the installer puts on your computer

| What | Where |
|---|---|
| The app, and Electron (the program that runs it) | `~/.local/share/lodestar2` |
| Helpers: Legendary (Epic Games), umu-run (Windows games), Ludusavi (finding saves) | `~/.local/share/lodestar2/tools` |
| The `lodestar` command | `~/.local/bin/lodestar` |
| The app-menu entry | `~/.local/share/applications/lodestar.desktop` |
| Your settings and themes, made when you first start it | `~/.config/Lodestar2` |

Every download is checked against a known checksum before it is used. A helper you already
have installed is not downloaded again. To skip the helpers:

```
curl -fsSL https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.sh | sh -s -- --no-helpers
```

## If something goes wrong

- **"lodestar: command not found":** use the app menu, or type `~/.local/bin/lodestar`.
- **Nothing opens:** run `lodestar` in a terminal and read what it prints.
- **A helper could not be fetched:** the install still finishes. Run `lodestar --update` later
  to try again.

Windows is not supported yet.
