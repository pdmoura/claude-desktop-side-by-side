# Security Policy

These scripts run on people's computers with their user permissions, so security reports are taken seriously.

## Reporting a vulnerability

**Please don't open a public issue.** Instead, report it privately through GitHub:

1. Go to the [Security tab](../../security) of this repository.
2. Click **Report a vulnerability**.
3. Describe the problem, how to reproduce it, and its impact.

You should get a response within a few days. Once a fix is ready, it will be released and you'll be credited, unless you prefer not to be.

## Scope

In scope: the scripts in this repository (`claude-profile.ps1`, `claude-profile.sh`), for example command injection through profile names or URLs, or unsafe file handling.

Out of scope: vulnerabilities in Claude Desktop itself. Report those to Anthropic through their [responsible disclosure program](https://www.anthropic.com/responsible-disclosure-policy).

## Supported versions

Only the latest version on the `main` branch is supported.
