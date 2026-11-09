# Claude Desktop Side by Side

**English** | [Português (Brasil)](README.pt-BR.md) | [Español](README.es.md)

<p align="center">
  <img src="docs/two-accounts-taskbar.jpg" alt="Two Claude Desktop icons on the Windows taskbar: the main account in orange and a second account in blue" width="720">
</p>
<p align="center"><b>Your main Claude account in orange, a second account in blue.<br>Both open at the same time, each with its own taskbar button.</b></p>

> [!IMPORTANT]
> **Sign in to each extra profile with "Continue with email": enter your email, then type the code you receive into the app. Don't click the link in the email, and don't use "Continue with Google".**
> Google sign-in (and the link in the email) sends you back to your main Claude window, so the new profile never finishes signing in. [Details](#sign-in-important)

Run **two or more Claude Desktop accounts at the same time**, for example a personal account and a work account, or accounts for two different companies. Each one gets its own window and its own **colored icon**.

No more logging out and back in to switch accounts.

**Jump to:** [Install on Windows](#install-windows) · [Install on macOS](#macos-experimental) · [Sign in](#sign-in-important) · [`/handoff`](#handoff)

| Platform | Status | What you get |
|---|---|---|
| **Windows 10/11** | ✅ Tested | Separate accounts side by side, colored desktop/Start-menu shortcut **and colored taskbar button**, plus [`/handoff`](#handoff) to continue a Claude Code conversation in another account |
| **macOS** | 🧪 Experimental, untested | Separate accounts side by side, colored launcher app (Dock/Launchpad/Spotlight). The running window keeps the normal Claude Dock icon |

> **Unofficial community workaround.** Not affiliated with, endorsed by, or supported by Anthropic. It relies on standard Electron and OS behavior, not on a documented Claude feature, so an app update could break it. Native multi-account support is requested in [anthropics/claude-code#18435](https://github.com/anthropics/claude-code/issues/18435). If you want it too, add a 👍 there.

## How it works

- Each profile is a separate Claude Desktop instance started with Electron's `--user-data-dir` switch, so it has its **own login, settings and history**. Your normal Claude Desktop is untouched and stays your "main" account.
- The colored icon is generated **locally** from your own installed Claude app by shifting its hue. Nothing is downloaded.
- On Windows, the launcher also gives the profile's window its own taskbar identity (AppUserModelID), so it gets its own colored taskbar button.

---

## Windows

### Requirements

- Windows 10 or 11
- Claude Desktop from [claude.ai/download](https://claude.ai/download) or the Microsoft Store
- Windows PowerShell 5.1 (built in)

Tested on Windows 11 with Claude Desktop 4.23118 (Microsoft Store/MSIX version). The classic installer is supported by the script but less tested. Reports are welcome.

<a id="install-windows"></a>
### Install a profile

There are two ways to install. Both do exactly the same thing, so pick one.

#### Quick install (one line)

1. Open the **Start** menu, type `powershell` and press **Enter**. Command Prompt (`cmd`) works too.
2. Copy this line, paste it into the window (**Ctrl+V** or right-click) and press **Enter**:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -Command "cd ([IO.Path]::GetTempPath()); iwr https://github.com/pdmoura/claude-desktop-side-by-side/archive/refs/heads/main.zip -OutFile claude-side-by-side.zip -UseBasicParsing; Expand-Archive claude-side-by-side.zip claude-side-by-side -Force; & .\claude-side-by-side\claude-desktop-side-by-side-main\claude-profile.ps1 -Install -Name Work -Color blue"
   ```

   The end of the line, `-Name Work -Color blue`, is the account's name and its icon color. You can change them before pressing Enter: see [Options](#install-options).

This downloads the current version of this project to your Temp folder and runs the installer right away. If you'd rather read the scripts before running them, use the step-by-step way below.

#### Step by step (download first)

1. **Download the files.** At the top of this page, click the green **Code** button, then **Download ZIP**. In your Downloads folder, right-click the ZIP file and choose **Extract All**. If you use Git, you can clone it instead: `git clone https://github.com/pdmoura/claude-desktop-side-by-side.git`

   Read the scripts before you run them, as you should with any script from the internet. [`claude-profile.ps1`](claude-profile.ps1) is the installer. [`claude-handoff.ps1`](claude-handoff.ps1) and the [`skills`](skills/handoff/SKILL.md) folder add [`/handoff`](#handoff).
2. **Open PowerShell in that folder.** Open the extracted folder in File Explorer. If all you see is another folder with the same name, open that one too: you're in the right place when you see `claude-profile.ps1`. Then click the address bar at the top, type `powershell` and press **Enter**. A PowerShell window opens, already in the right folder.
3. **Run the installer.** Copy this line, paste it into the PowerShell window (**Ctrl+V** or right-click) and press **Enter**:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\claude-profile.ps1 -Install -Name Work -Color blue
   ```

<a id="install-options"></a>
#### Options

These go at the end of the install line, whichever way you install. In the quick install, keep them inside the closing `"`.

- `-Name`: a name for this account. Letters, numbers, `-` and `_` only (e.g. `Work`, `AcmeCorp`, `Personal`).
- `-Color`: the icon color. See [Colors](#colors).
- **Optional, only if you use Claude Code in a terminal:** add `-Cli` after the color. It also creates a `claude-work` command that opens Claude Code in the terminal with this account. It needs [Claude Code](https://docs.claude.com/en/docs/claude-code) installed (the `claude` command), and asks you to log in the first time.

#### What you should see

When it finishes, the window shows `Profile 'Work' installed.` and a **Claude (Work)** shortcut appears on your desktop and in the Start menu. If you get an error message instead, [open an issue](../../issues) and paste the message there.

The installer also copies the scripts to `%LOCALAPPDATA%\ClaudeProfiles\` and sets up [`/handoff`](#handoff) for every account. Everything is installed for your Windows user, not inside the downloaded folder, so you can delete that folder afterwards: the shortcuts keep working and `/handoff` works in every project.

#### Next steps

1. **Sign in.** Open **Claude (Work)**, click **Continue with email**, enter your email, then **type the code** you receive by email into the app. Don't click the link in the email, and don't use Google ([why](#sign-in-important)).
2. **Add more accounts.** Run the install line again with another name and color for each extra account.

### Everyday use

- Open each account from its shortcut. The main app and all profiles can run at the same time.
- **Taskbar:** a few seconds after opening, the profile's taskbar button switches to its color and separates from the main Claude button.
- **Pin it:** right-click the *colored taskbar button* of the running profile and choose **Pin to taskbar**. The pin keeps the color and opens that profile.
- If a profile window was opened some other way (not via its shortcut or pin), it may show the default icon. Open it from the shortcut again to fix it.

### Other commands

```powershell
$cp = "$env:LOCALAPPDATA\ClaudeProfiles\claude-profile.ps1"

powershell -ExecutionPolicy Bypass -File $cp -List                               # list profiles
powershell -ExecutionPolicy Bypass -File $cp -Install -Name Work -Color purple    # change color (keeps login)
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Work                # remove shortcuts, keep login data
powershell -ExecutionPolicy Bypass -File $cp -Uninstall -Name Work -RemoveData    # remove everything for that profile
powershell -ExecutionPolicy Bypass -File $cp -Name Work -OpenUrl "claude://..."   # send a sign-in link to this profile
```

Close the profile window (and quit it from the system tray) before uninstalling.

After changing a color, open the profile from its shortcut again. If you pinned it to the taskbar, unpin and re-pin it, because Windows caches pinned icons.

<a id="handoff"></a>
### Continue a conversation in another account (/handoff)

**This is only for Claude Code**: the **Code** tab in Claude Desktop, or `claude` in a terminal. Regular chats aren't affected. If you don't use Claude Code, you can skip this section.

A Claude Code conversation normally stays in the account where you started it. With `/handoff` you can move it to another account and keep going there, with everything that was said so far. You can move it back the same way later.

**Example:** you started a conversation in your main Claude window and want to continue it in **Claude (Work)**.

1. In the conversation, type `/handoff Work` and send it. Use the name you gave the profile when you installed it. Claude does the rest and tells you when it's done.
2. Don't send any more messages in that conversation in the main window.
3. If **Claude (Work)** is already open, close it completely: right-click its icon next to the clock (in the system tray) and choose **Quit**. Then open it again from its shortcut.
4. In **Claude (Work)**, go to the **Code** tab. The conversation is in the sidebar, under the same project folder. Click it and carry on.

To bring it back, type `/handoff Desktop` in **Claude (Work)** (`Desktop` means the account of your main Claude window) and follow the same steps.

**In a terminal** (if you installed with `-Cli`): after the handoff, open a terminal in the same project folder, run the account's command (for example `claude-work`), type `/resume` and pick the conversation.

| Type this | What it does |
|---|---|
| `/handoff Work` | Moves this conversation to the Work account: its window and its `claude-work` command |
| `/handoff Desktop` | Moves it to the account of your main Claude window |
| `/handoff refresh` | Updates this account's window and its terminal command to the same copy, so you can switch between them |

**Good to know**

- **Hand off right before you switch.** Each window and each terminal command keeps its own copy of the conversation, and a handoff copies it as it is at that moment. Messages you send afterwards stay where you sent them. This also applies to switching between a window and the terminal of the same account: use `/handoff refresh` for that.
- **Archive, don't delete.** To remove a moved conversation from one account, archive it there. Deleting it can also delete it for the other accounts.
- **"Continued in more than one place":** this means messages were sent in two accounts without a handoff in between. Nothing is changed. Claude shows which copies have messages the others don't and asks which one to keep. The others are saved as backup files (`.diverged`), never deleted.
- **New accounts** get `/handoff` automatically the next time you install a profile.
- **Experimental, Windows only.** It depends on how Claude stores conversations today, which isn't documented. If an update changes that, `/handoff` stops with an error instead of changing anything.

<details>
<summary>Terminal commands (advanced)</summary>

Run these in PowerShell, in the project folder. If `claude-handoff` isn't found, use `powershell -ExecutionPolicy Bypass -File "$env:LOCALAPPDATA\ClaudeProfiles\claude-handoff.ps1"` in its place.

```powershell
claude-handoff -List                         # accounts, and the conversations of this folder
claude-handoff -To Work                      # hand off the newest conversation of this folder
claude-handoff -To Work -Session 12eb8934    # a specific conversation (id from -List)
claude-handoff -To Work -Prefer Desktop      # continued in two places: keep the Desktop copy
claude-handoff -To Work -DryRun              # show what would happen, change nothing
claude-handoff -Install                      # add /handoff to every account now
```

</details>

### Where data lives

| | Location |
|---|---|
| Scripts + icons | `%LOCALAPPDATA%\ClaudeProfiles\` |
| Profile data (Store version) | `%LOCALAPPDATA%\Packages\Claude_<id>\LocalCache\Roaming\Claude-<Name>` (Windows redirects app data for Store apps) |
| Profile data (classic installer) | `%APPDATA%\Claude-<Name>` |
| Claude Code conversations, desktop app (every window) | `%USERPROFILE%\.claude\projects` |
| Claude Code conversations, `claude-<name>` command | `%USERPROFILE%\.claude-<name>\projects` |
| `/handoff` skill | `skills\handoff` inside each of the two folders above |

---

## macOS (experimental)

> 🧪 **Untested.** The macOS script uses the same Electron mechanism as the Windows one, but it hasn't been run on a Mac yet. If you try it, please file a [macOS test report](../../issues/new?template=macos_test_report.yml), even if everything worked.

### What to expect

- ✅ Separate accounts side by side (each profile is its own Claude instance with its own data folder).
- ✅ A **Claude (Work).app** launcher in `~/Applications` with a recolored icon, which you can keep in the Dock or open from Spotlight/Launchpad.
- ❌ **The running window still shows the normal orange Claude icon in the Dock.** macOS doesn't let another program change a running app's Dock icon. That would require modifying Claude.app itself, which breaks its signature and updates, so this project doesn't do it. Tell the windows apart by the account shown inside the app.

### Install a profile

```bash
curl -O https://raw.githubusercontent.com/pdmoura/claude-desktop-side-by-side/main/claude-profile.sh
less claude-profile.sh           # read it first
chmod +x claude-profile.sh
./claude-profile.sh install Work blue
```

Then open **Claude (Work)** from Spotlight, Launchpad or `~/Applications`, drag it to the Dock if you like, and sign in: click **Continue with email**, enter your email, then **type the code** you receive by email into the app. Don't click the link in the email, and don't use Google ([why](#sign-in-important)).

### Other commands

```bash
cp="$HOME/Library/Application Support/ClaudeProfiles/claude-profile.sh"

"$cp" list                             # list profiles
"$cp" install Work purple              # change color (keeps login)
"$cp" launch Work                      # open without the launcher app
"$cp" uninstall Work                   # remove the launcher, keep login data
"$cp" uninstall Work --remove-data     # remove everything for that profile
"$cp" launch Work "claude://..."       # try sending a sign-in link to this profile (unverified on macOS)
```

Profile data lives in `~/Library/Application Support/Claude-<Name>`.

### Requirements

macOS with Claude Desktop in `/Applications` or `~/Applications`. Only built-in tools are used (`open`, `sips`, `iconutil`, `osascript`/Core Image).

---

## Sign in (important)

This applies to every platform. Open the profile, then:

1. Click **Continue with email**, not "Continue with Google".
2. Enter the account's email (Gmail and Google Workspace addresses work too).
3. **Type the code** from the email into the app. Don't click the link in the email.

**Why:** Google sign-in and the email link both return to the app through a `claude://` link. The operating system delivers that link to your *main* Claude app, so the profile window would wait forever. The email code keeps the whole sign-in inside the profile window. You only do this once, and the profile stays signed in.

If your organization only allows Google/SSO sign-in, copy the `claude://...` link from the browser instead of letting it open Claude, and pass it to the profile with the `-OpenUrl` (Windows) or `launch Work "claude://..."` (macOS) command shown above.

## Colors

`red`, `orange`, `yellow`, `green`, `teal`, `blue`, `indigo`, `purple`, `pink`, or any hue number from `0` to `360` (for example `195` for sky blue or `300` for magenta).

The color is a hue shift of the Claude logo, so it keeps Claude's brightness and saturation. Black, white, grey and exact brand hex colors aren't supported.

## Limitations

- Unofficial: a Claude Desktop update could change how this behaves.
- Each profile is a full app instance, so it uses as much memory as a second Claude window would.
- Windows: Alt+Tab may still show the default Claude icon. A small hidden PowerShell process runs for a few seconds when a profile opens (to set the taskbar icon), then exits.
- `/handoff` relies on undocumented Claude storage formats, and its copies are snapshots: see [/handoff](#handoff).
- macOS: see [What to expect](#what-to-expect).

## Contributing

Bug reports, macOS test reports and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for how changes are reviewed and merged, and [SECURITY.md](SECURITY.md) to report a vulnerability privately.

## License

MIT. See [LICENSE](LICENSE).
