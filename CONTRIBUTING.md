# Contributing

Thanks for helping! Contributions of all sizes are welcome: bug reports, macOS test reports, docs fixes and code.

## Before you start

- **Bug or question?** Open an [issue](../../issues/new/choose) using one of the templates.
- **Tried the macOS version?** Please file a [macOS test report](../../issues/new?template=macos_test_report.yml), even if everything worked. That's how it stops being "experimental".
- **Bigger change or new feature?** Open an issue first so we can agree on the approach before you write code.
- **Security problem?** Don't open a public issue. See [SECURITY.md](SECURITY.md).

## How changes get in

1. Fork the repo and create a branch from `main` (e.g. `fix/taskbar-icon-classic-installer`).
2. Make your change, keeping the [project principles](#project-principles) in mind.
3. Test it (see [Testing](#testing)) and fill in the pull request checklist.
4. Open a pull request against `main`.

Every pull request is reviewed by the maintainer, has to pass the automatic checks (PSScriptAnalyzer, ShellCheck and a macOS bash 3.2 syntax check), and is **squash-merged**, so each PR becomes one clean commit on `main`. Nobody can push to `main` directly.

## Project principles

- **Built-in tools only.** The scripts must not download anything or require installing extra software. Windows uses Windows PowerShell 5.1 and .NET; macOS uses `open`, `sips`, `iconutil` and `osascript`.
- **Never modify Claude.app or Claude.exe.** No patching, re-signing or copying the app. Profiles are separate instances of the unmodified app.
- **No telemetry, no network calls.**
- **Compatibility:** the PowerShell script must run on Windows PowerShell 5.1 (not only PowerShell 7). The shell script must run on macOS's built-in **bash 3.2**, so no associative arrays, `${var,,}`, `mapfile`, etc.
- **Be honest in the docs.** If something is untested or doesn't work, say so in the README.

## Testing

Please test on a real machine and say in your PR what you tested on:

- **Windows:** install a throwaway profile (`-Install -Name ZzTest -Color green`), open it from the shortcut, check the colored taskbar button, then `-Uninstall -Name ZzTest -RemoveData` and confirm nothing is left behind. Mention whether you have the Microsoft Store or the classic installer version of Claude.
- **macOS:** `install ZzTest green`, open the launcher, sign in with the email code, `list`, then `uninstall ZzTest --remove-data`. Mention your macOS version and Apple Silicon or Intel.

## Style

- Keep changes focused: one fix or feature per PR.
- Match the existing style, and comment anything non-obvious (especially Windows/macOS API calls).
- Update the README when behavior or commands change.

## Documentation languages

The README is available in English ([README.md](README.md)), Brazilian Portuguese ([README.pt-BR.md](README.pt-BR.md)) and Spanish ([README.es.md](README.es.md)). English is the source of truth.

- If your change affects the docs, update all three files if you can. If you can't translate, update the English README and say in your PR which translations still need updating. The maintainer or another contributor will follow up.
- Keep the same structure in every language, including the `<a id="...">` anchors, so links work in all versions.
- Command names, flags and color names (`-Install`, `blue`...) stay in English in every language.
- Issues and pull requests can be written in English, Portuguese or Spanish.

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE) and that you'll follow the [Code of Conduct](CODE_OF_CONDUCT.md).
