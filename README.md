# Firefox Classic Theme

A Firefox look that stays close to the classic Photon design, built on
[Lepton](https://github.com/black7375/Firefox-UI-Fix) by
[@black7375](https://github.com/black7375).

This project bundles the **Lepton Photon-Style** release unchanged, plus a
small set of fixes for the new look Firefox 157 introduced:

- The URL bar and search bar keep slightly rounded corners instead of
  turning into pills.
- The URL bar and search bar no longer grow past the toolbar when you type.
- Hovering a tab shows the blue line, like the selected tab, instead of a
  grey one.
- The tab close button is square.

All the fixes live in [`chrome/classic.css`](chrome/classic.css). Everything
else under `chrome/css`, `chrome/icons` and `user.js` comes from Lepton
[`LEPTON_VERSION`](LEPTON_VERSION).

## Install

Close Firefox first, or restart it after installing.

**macOS and Linux**

```sh
curl -fsSL https://raw.githubusercontent.com/axelberardino/firefox-classic-theme/main/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/axelberardino/firefox-classic-theme/main/install.ps1 | iex
```

This installs into the profile Firefox opens by default. To choose
another profile, or all of them, clone the repository and run the script
yourself:

```sh
git clone https://github.com/axelberardino/firefox-classic-theme.git
cd firefox-classic-theme
./install.sh --list                 # show the profiles found
./install.sh --profile "<folder>"   # one profile
./install.sh --all                  # every profile
```

On Windows, the options are `-List`, `-ProfileDir "<folder>"` and `-All`.
You can also find your profile folder in Firefox under `about:profiles`.

The first time, the installer saves your existing `chrome` folder and
`user.js` as `chrome.before-classic-theme` and `user.js.before-classic-theme`.

## Update

Run the install command again. Your override files (see below) are kept.

## Uninstall

```sh
./install.sh --uninstall          # macOS and Linux
.\install.ps1 -Uninstall          # Windows
```

This removes the theme and puts back the `chrome` folder and `user.js` you
had before the first install. Preferences set by `user.js` stay in
Firefox until you reset them in `about:config`.

## Your own tweaks

Put your changes in these files and they will survive updates:

| File | For |
| --- | --- |
| `<profile>/chrome/userChrome-overrides.css` | Firefox's own interface |
| `<profile>/chrome/userContent-overrides.css` | Web pages and built-in pages |
| `<profile>/user-overrides.js` | Preferences, added to the end of `user.js` |

Lepton's options (the `userChrome.*` preferences) are listed in
[its wiki](https://github.com/black7375/Firefox-UI-Fix/wiki/Options). Set
them in `user-overrides.js` and run the installer again.

## Updating Lepton (maintainers)

```sh
scripts/update-lepton.sh           # latest Lepton release
scripts/update-lepton.sh v8.7.6    # a given release
```

This replaces the Lepton files and keeps `chrome/classic.css`,
`chrome/userChrome.css` and `chrome/userContent.css`. If Lepton changed its
own `userChrome.css` or `userContent.css`, the script prints the difference
(the originals are kept in `upstream/`) so it can be carried over.

## Credits and license

Almost all of this theme is [Lepton](https://github.com/black7375/Firefox-UI-Fix)
by [@black7375](https://github.com/black7375) and its
contributors, listed in [CREDITS](CREDITS). Please report Lepton issues
upstream, and only issues with the fixes above here.

Like Lepton, this project is released under the
[Mozilla Public License 2.0](LICENSE).
