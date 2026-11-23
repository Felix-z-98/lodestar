# Lodestar

A customizable game launcher for Linux and Windows. It gathers your Steam, GOG and Epic games
in one library, with a store, news, your saves, and themes you make yourself.

## Install on Windows

1. Press the Start button, type `PowerShell` and open it.
2. Paste this line and press Enter:

```
irm https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.ps1 | iex
```

3. Start **Lodestar** from the Start menu.

It installs for your user only, in `%LOCALAPPDATA%\Lodestar2`, and needs no admin rights. The
first install downloads about 160 MB. It needs Windows 10 or 11, 64-bit.

- **Update:** run the same line again (close Lodestar first).
- **Remove:** open `%LOCALAPPDATA%\Lodestar2` and run `Uninstall Lodestar.cmd`. Your settings,
  themes, sign-ins and games are kept.

The Windows version is new. If something does not work, tell Felix what you saw.

## Install on Linux

Open a terminal and paste this line:

```
curl -fsSL https://raw.githubusercontent.com/Felix-z-98/lodestar/main/install.sh | sh
```

Then start **Lodestar** from your app menu, or type `lodestar`.

It installs for your user only and never asks for a password. The first install downloads
about 130 MB.

## Update and remove on Linux

| To do this | Type this |
|---|---|
| Get the newest version | `lodestar --update` |
| Remove Lodestar | `lodestar --uninstall` |

Removing Lodestar keeps your settings, themes, sign-ins and games.

## What you need on Linux

- Linux on a 64-bit PC (Intel/AMD, or ARM).
- `curl` or `wget`, and `unzip`. Most systems have them already.
- Steam, if you want your Steam games to show up. GOG and Epic sign-ins are inside the app.
- `python3`, only for starting Windows games from GOG and Epic.

## What the Linux installer puts on your computer

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
