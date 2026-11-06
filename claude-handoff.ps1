<#
.SYNOPSIS
  claude-handoff (EXPERIMENTAL): continue a Claude Code conversation in another account, from the
  desktop app or the CLI, and find it there on the sidebar and in /resume.

.DESCRIPTION
  Part of Claude Desktop Side by Side - unofficial, not affiliated with Anthropic.

  Where conversations live:
  - Every Claude Desktop window, whatever account is signed in, reads %USERPROFILE%\.claude\projects.
  - Each CLI account (claude-<name>) reads its own %USERPROFILE%\.claude-<name>\projects.
  - The desktop sidebar is a per-account list of small entry files, in
    <app data folder>\claude-code-sessions\<account id>\<organization id>\local_<id>.json

  A handoff finds the most complete copy of the conversation in any of those folders, copies it to
  .claude (so the desktop app can open it) and to the target account's CLI folder (so /resume finds
  it), and adds it to the target account's sidebar list, or refreshes the entry if it's there.

  Copies are compared by the messages you typed. If two copies each have messages the other lacks,
  the conversation was continued in two places: the script stops and asks which one to keep with
  -Prefer. The other copy is first saved next to it as <id>.jsonl.diverged-<date>.

  It never deletes or archives anything. If the app's files don't look the way this script expects
  (an update changed them), it stops before writing anything.

  Rules for a safe round trip:
  - Use the conversation in one place at a time, and hand it off whenever you switch, including
    between a desktop window and a CLI of the same account: they read different folders.
  - If the desktop window you arrive in is already open, restart it, so it reloads its list and the
    conversation from disk. The script tells you when that's needed.

.EXAMPLE
  claude-handoff -To Fullpond                 # this conversation (inside Claude), or the newest one in this folder
.EXAMPLE
  claude-handoff -To Pando -Session 12eb8934  # a specific conversation (its id or first characters)
.EXAMPLE
  claude-handoff -To refresh                  # inside Claude: sync this account's desktop and CLI copies
.EXAMPLE
  claude-handoff -To Desktop                  # the account the main Claude window is signed in to
.EXAMPLE
  claude-handoff -List                        # accounts, windows and this folder's conversations
.EXAMPLE
  claude-handoff -To Fullpond -Prefer Pando   # it was continued in two places: keep the Pando copy
.EXAMPLE
  claude-handoff -To Fullpond -DryRun         # show what would happen
.EXAMPLE
  claude-handoff -Install                     # add the /handoff skill to every account, and this command
#>
param(
  [string]$To,
  [string]$Session,
  [string]$Path = (Get-Location).ProviderPath,
  [string]$Prefer,
  [switch]$List,
  [switch]$Install,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
trap { Write-Host "claude-handoff: $($_.Exception.Message)" -ForegroundColor Red; exit 1 }
$UserHome = $env:USERPROFILE
$SharedRoot = Join-Path $UserHome '.claude'    # what every Claude Desktop window reads
$Marker = 'Created by claude-handoff.ps1 (github.com/pdmoura/claude-desktop-side-by-side)'
$StringSet = 'System.Collections.Generic.HashSet[string]'

function Read-Json([string]$file) {
  try { Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { $null }
}
function Write-Utf8([string]$file, [string]$text) {
  [IO.File]::WriteAllText($file, $text, (New-Object Text.UTF8Encoding $false))
}
function Get-Prop($obj, [string]$name) {
  if ($null -ne $obj -and $obj.PSObject.Properties[$name]) { $obj.$name } else { $null }
}
function Get-ProjectKey([string]$p) { ([IO.Path]::GetFullPath($p).TrimEnd('\')) -replace '[^A-Za-z0-9]', '-' }
function Get-NowMs { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }
function Copy-Tree([string]$from, [string]$to) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  robocopy $from $to /E /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Copy failed: $from -> $to (robocopy code $LASTEXITCODE)" }
}

# --- Account folders (.claude, .claude-<name>): which account each one is signed in to ---------------
$accounts = @(Get-ChildItem -LiteralPath $UserHome -Directory -Force -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match '^\.claude(-[A-Za-z0-9_-]+)?$' } | ForEach-Object {
    $shared = $_.Name -eq '.claude'
    $cfg = if ($shared) { Join-Path $UserHome '.claude.json' } else { Join-Path $_.FullName '.claude.json' }
    $acc = Get-Prop (Read-Json $cfg) 'oauthAccount'
    $label = if ($shared) { 'Desktop' } else { $s = $_.Name -replace '^\.claude-', ''; $s.Substring(0, 1).ToUpper() + $s.Substring(1) }
    [pscustomobject]@{
      Label = $label; Root = $_.FullName; Shared = $shared; Command = if ($shared) { 'claude' } else { 'claude-' + $label.ToLower() }
      AccountId = Get-Prop $acc 'accountUuid'; OrgId = Get-Prop $acc 'organizationUuid'; Email = Get-Prop $acc 'emailAddress'
    }
  })
if (-not ($accounts | Where-Object { $_.Shared })) { throw "$SharedRoot was not found. Is Claude Code installed?" }

function Get-AccountName([string]$accountId) {
  $hit = $accounts | Where-Object { $_.AccountId -eq $accountId -and $_.Email } | Select-Object -First 1
  if ($hit) { $hit.Email } else { $accountId }
}

# --- The /handoff skill in every account, and the claude-handoff command -------------------------------
function Install-Handoff([bool]$verbose) {
  $canonical = Join-Path $SharedRoot 'skills\handoff\SKILL.md'
  if (-not (Test-Path -LiteralPath $canonical)) { if ($verbose) { Write-Host "  Skipped the skill: $canonical is missing." -ForegroundColor Yellow }; return }
  $wanted = [IO.File]::ReadAllText($canonical)
  foreach ($a in @($accounts | Where-Object { -not $_.Shared })) {
    $dest = Join-Path $a.Root 'skills\handoff\SKILL.md'
    if ((Test-Path -LiteralPath $dest) -and ([IO.File]::ReadAllText($dest) -ceq $wanted)) { continue }
    New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
    [IO.File]::WriteAllText($dest, $wanted, (New-Object Text.UTF8Encoding $false))
    if ($verbose) { Write-Host "  /handoff skill -> $($a.Command)" -ForegroundColor Green }
  }
  $cmd = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($cmd) {
    $launcher = Join-Path (Split-Path $cmd.Source) 'claude-handoff.cmd'
    if ((Test-Path -LiteralPath $launcher) -and -not (Select-String -LiteralPath $launcher -SimpleMatch $Marker -Quiet)) {
      if ($verbose) { Write-Host "  $launcher already exists and wasn't created by this script, so it was left alone." -ForegroundColor Yellow }
    } elseif (-not (Test-Path -LiteralPath $launcher)) {
      @(
        '@echo off'
        'rem claude-handoff: continue a conversation in another account'
        "rem $Marker"
        'powershell -NoProfile -ExecutionPolicy Bypass -File "%LOCALAPPDATA%\ClaudeProfiles\claude-handoff.ps1" %*'
      ) | Set-Content -LiteralPath $launcher -Encoding ASCII
      if ($verbose) { Write-Host '  claude-handoff command added' -ForegroundColor Green }
    }
  }
}
if ($Install) { Write-Host ''; Install-Handoff $true; Write-Host '  Done: /handoff is available in every account.'; exit 0 }

# --- Claude Desktop data folders: the main app and every claude-profile.ps1 window ---------------------
$rootProcs = @(Get-CimInstance Win32_Process -Filter "Name='Claude.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '--type=' })
$pkgRoaming = @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue |
  ForEach-Object { Join-Path $_.FullName 'LocalCache\Roaming' })

$candidates = @()
# Main window. Store app: %LOCALAPPDATA%\Claude-Data\claude_<id>, older Store builds: the package's Roaming\Claude,
# classic installer: %APPDATA%\Claude. The first one that holds a session list wins.
$candidates += @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Claude-Data') -Directory -Filter 'claude_*' -ErrorAction SilentlyContinue |
  ForEach-Object { [pscustomobject]@{ Name = 'Desktop'; Dir = $_.FullName } })
$candidates += @($pkgRoaming | ForEach-Object { [pscustomobject]@{ Name = 'Desktop'; Dir = (Join-Path $_ 'Claude') } })
$candidates += [pscustomobject]@{ Name = 'Desktop'; Dir = (Join-Path $env:APPDATA 'Claude') }
# Profile windows (Store app redirects %APPDATA%\Claude-<name> into the package, so check that first)
foreach ($p in @(Get-ChildItem (Join-Path $env:LOCALAPPDATA 'ClaudeProfiles') -Directory -ErrorAction SilentlyContinue)) {
  $candidates += @($pkgRoaming | ForEach-Object { [pscustomobject]@{ Name = $p.Name; Dir = (Join-Path $_ "Claude-$($p.Name)") } })
  $candidates += [pscustomobject]@{ Name = $p.Name; Dir = (Join-Path $env:APPDATA "Claude-$($p.Name)") }
}

$windows = @()
foreach ($c in $candidates) {
  if ($windows | Where-Object { $_.Name -eq $c.Name }) { continue }
  $sessions = Join-Path $c.Dir 'claude-code-sessions'
  if (-not (Test-Path -LiteralPath $sessions -PathType Container)) { continue }
  $running = if ($c.Name -eq 'Desktop') {
    [bool]@($rootProcs | Where-Object { $_.CommandLine -notmatch 'user-data-dir' }).Count
  } else {
    $pattern = 'user-data-dir="?[^"]*\\Claude-' + [regex]::Escape($c.Name) + '("|\s|$)'
    [bool]@($rootProcs | Where-Object { $_.CommandLine -match $pattern }).Count
  }
  $windows += [pscustomobject]@{
    Name = $c.Name; Dir = $c.Dir; Sessions = $sessions; Running = $running
    LastAccount = Get-Prop (Read-Json (Join-Path $c.Dir 'config.json')) 'lastKnownAccountUuid'
    Title = if ($c.Name -eq 'Desktop') { 'Claude' } else { "Claude ($($c.Name))" }
  }
}

# --- Reading a conversation file -----------------------------------------------------------------------
# One pass over the file: its title, model, start time, and the set of messages the user typed.
# "Typed" leaves out tool results and app-injected lines. Those differ between copies for harmless reasons:
# a handoff run from a live session copies the file before that turn finishes writing its last lines.
$genericTitles = @($accounts | ForEach-Object { $_.Label.ToUpper() }) + @($windows | ForEach-Object { $_.Name.ToUpper() })
$typedPattern = [regex]'"role":"user","content":(?:"|\[\{"type":"(?:text|image)")'
function Get-TranscriptInfo([string]$file) {
  $typed = New-Object $StringSet
  $title = $null; $firstText = $null; $model = $null; $started = $null
  $fs = New-Object IO.FileStream($file, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
  $reader = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
  try {
    while ($null -ne ($line = $reader.ReadLine())) {
      if (-not $line.EndsWith('}')) { continue }     # a line still being written
      if (-not $started) { $m = [regex]::Match($line, '"timestamp":"([^"]+)"'); if ($m.Success) { $started = $m.Groups[1].Value } }
      if ($line -match '^\{"type":"(custom-title|ai-title|summary)"') {
        try {
          $o = $line | ConvertFrom-Json
          $t = @((Get-Prop $o 'customTitle'), (Get-Prop $o 'aiTitle'), (Get-Prop $o 'summary')) | Where-Object { $_ } | Select-Object -First 1
          if ($t -and ($genericTitles -notcontains $t)) { $title = $t }   # skip titles that are just an account name
        } catch {}
        continue
      }
      if ($line.Contains('"type":"assistant"')) {
        $m = [regex]::Match($line, '"model":"(claude-[^"]+)"'); if ($m.Success) { $model = $m.Groups[1].Value }
        continue
      }
      if ($line.Contains('"type":"user"') -and $typedPattern.IsMatch($line) -and -not $line.Contains('"toolUseResult"') -and
          -not $line.Contains('"isMeta":true') -and -not $line.Contains('"isCompactSummary":true') -and -not $line.Contains('"isSidechain":true')) {
        [void]$typed.Add($line)
        if (-not $firstText) {
          try {
            $c = ($line | ConvertFrom-Json).message.content
            $texts = if ($c -is [string]) { @($c) } else { @($c | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) }
            $firstText = $texts | Where-Object { $_ -and $_ -notmatch '^\s*<' } | Select-Object -First 1
          } catch {}
        }
      }
    }
  } finally { $reader.Dispose() }
  $name = if ($title) { $title } elseif ($firstText) { $firstText } else { 'Handed-off conversation' }
  $name = ($name -replace '\s+', ' ').Trim()
  if ($name.Length -gt 60) { $name = $name.Substring(0, 57) + '...' }
  [pscustomobject]@{ Title = $name; Model = $model; Started = $started; Typed = $typed }
}

# Every copy of every conversation of this folder, across all account folders
$Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
$projectKey = Get-ProjectKey $Path
$byId = @{}
foreach ($a in $accounts) {
  $dir = Join-Path $a.Root "projects\$projectKey"
  foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter *.jsonl -File -ErrorAction SilentlyContinue)) {
    if ($f.BaseName -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F-]{27}$') { continue }
    if (-not $byId.ContainsKey($f.BaseName)) { $byId[$f.BaseName] = @() }
    $byId[$f.BaseName] += [pscustomobject]@{ Account = $a; File = $f; Dir = $dir }
  }
}

if ($List) {
  Write-Host ''
  Write-Host 'Claude Desktop windows' -ForegroundColor Cyan
  foreach ($w in $windows) {
    $state = if ($w.Running) { 'running' } else { 'closed' }
    Write-Host ("  {0,-10} {1,-8} signed in as {2}" -f $w.Name, $state, (Get-AccountName $w.LastAccount))
  }
  Write-Host ''
  Write-Host 'Account folders' -ForegroundColor Cyan
  foreach ($a in $accounts) { Write-Host ("  {0,-10} {1,-16} {2}" -f $a.Label, $a.Command, $a.Email) }
  Write-Host ''
  Write-Host "Conversations in $Path" -ForegroundColor Cyan
  if (-not $byId.Count) { Write-Host '  (none)' }
  $rows = foreach ($id in $byId.Keys) {
    $newest = $byId[$id] | Sort-Object { $_.File.LastWriteTimeUtc } -Descending | Select-Object -First 1
    [pscustomobject]@{ Id = $id; When = $newest.File.LastWriteTime; In = (@($byId[$id] | ForEach-Object { $_.Account.Label }) -join ', '); Title = (Get-TranscriptInfo $newest.File.FullName).Title }
  }
  foreach ($r in @($rows | Sort-Object When -Descending)) { Write-Host ("  {0}  {1}  {2,-26} {3}" -f $r.Id.Substring(0, 8), $r.When.ToString('dd/MM HH:mm'), $r.In, $r.Title) }
  Write-Host ''
  Write-Host 'Use a window name, a folder name or an email with -To, and an id above with -Session.' -ForegroundColor DarkGray
  exit 0
}
if (-not $To) { throw 'Say which account to hand the conversation to, e.g. -To Fullpond (see -List).' }

# --- The account this runs in (inside a Claude session), and the target account -----------------------
# Desktop sessions say which account they use; CLI sessions started with claude-<name> have CLAUDE_CONFIG_DIR.
$currentAccount = $null
if ($env:CLAUDE_CODE_ACCOUNT_UUID) { $currentAccount = $env:CLAUDE_CODE_ACCOUNT_UUID }
elseif ($env:CLAUDE_CONFIG_DIR) {
  $cfgDir = [IO.Path]::GetFullPath($env:CLAUDE_CONFIG_DIR).TrimEnd('\')
  $currentAccount = ($accounts | Where-Object { $_.Root.TrimEnd('\') -ieq $cfgDir } | Select-Object -First 1).AccountId
} elseif ($env:CLAUDE_CODE_SESSION_ID) {
  $currentAccount = ($accounts | Where-Object { $_.Shared } | Select-Object -First 1).AccountId
}
$refresh = $To -in @('refresh', 'sync')

$targetAccount = $null
if ($refresh) {
  if (-not $currentAccount) { throw "Couldn't tell which account this is (refresh works inside a Claude session). Use -To <account> instead." }
  $targetAccount = $currentAccount
}
$w = $windows | Where-Object { $_.Name -ieq $To } | Select-Object -First 1
if (-not $targetAccount -and $w) { $targetAccount = $w.LastAccount }
if (-not $targetAccount) {
  $a = $accounts | Where-Object { $_.Label -ieq $To -or $_.Command -ieq $To -or $_.Email -ieq $To -or (Split-Path $_.Root -Leaf) -ieq $To } | Select-Object -First 1
  if ($a) { $targetAccount = $a.AccountId }
}
if (-not $targetAccount) { throw "Unknown account '$To'. Run with -List to see the names you can use." }

$targetOrg = ($accounts | Where-Object { $_.AccountId -eq $targetAccount -and $_.OrgId } | Select-Object -First 1).OrgId
if (-not $targetOrg) {
  $orgs = @($windows | ForEach-Object { Get-ChildItem (Join-Path $_.Sessions $targetAccount) -Directory -ErrorAction SilentlyContinue } |
            ForEach-Object { $_.Name } | Sort-Object -Unique)
  if ($orgs.Count -eq 1) { $targetOrg = $orgs[0] }
  else { throw "Couldn't tell which organization of $(Get-AccountName $targetAccount) to use. Sign in to it once with its CLI command (claude-<name>) and try again." }
}
$targetWindows = @($windows | Where-Object {
  $_.LastAccount -eq $targetAccount -or (Test-Path -LiteralPath (Join-Path $_.Sessions "$targetAccount\$targetOrg") -PathType Container)
})

# --- Which conversation -------------------------------------------------------------------------------
# -Session wins. Inside a Claude session the id is in CLAUDE_CODE_SESSION_ID. Otherwise: the newest one here.
$cliId = $null
if ($Session) {
  $hits = @($byId.Keys | Where-Object { $_ -like "$Session*" })
  if ($hits.Count -gt 1) { throw "'$Session' matches more than one conversation; give more of the id." }
  if (-not $hits) { throw "No conversation '$Session' found for $Path in any account folder. Is this the folder it was started in?" }
  $cliId = $hits[0]
} elseif ($env:CLAUDE_CODE_SESSION_ID -and $byId.ContainsKey($env:CLAUDE_CODE_SESSION_ID)) {
  $cliId = $env:CLAUDE_CODE_SESSION_ID
} else {
  if (-not $byId.Count) { throw "No conversations found for $Path in any account folder. Is this the folder it was started in?" }
  $cliId = $byId.Keys | Sort-Object { ($byId[$_] | ForEach-Object { $_.File.LastWriteTimeUtc } | Measure-Object -Maximum).Maximum } -Descending | Select-Object -First 1
}

# --- Find the most complete copy; stop if it was continued in two places --------------------------------
$copies = @($byId[$cliId] | ForEach-Object {
  [pscustomobject]@{ Account = $_.Account; File = $_.File; Dir = $_.Dir; Info = (Get-TranscriptInfo $_.File.FullName); Only = 0; Missing = 0 }
})
$allTyped = New-Object $StringSet
foreach ($c in $copies) { $allTyped.UnionWith($c.Info.Typed) }
if ($allTyped.Count -eq 0) { throw "No typed messages were recognized in this conversation, so its copies can't be compared (an update may have changed the file format). Nothing was written." }
foreach ($c in $copies) {
  $lacking = [System.Collections.Generic.HashSet[string]]::new($allTyped); $lacking.ExceptWith($c.Info.Typed)
  $c.Missing = $lacking.Count
  $only = [System.Collections.Generic.HashSet[string]]::new($c.Info.Typed)
  foreach ($other in $copies) { if ($other -ne $c) { $only.ExceptWith($other.Info.Typed) } }
  $c.Only = $only.Count
}
$complete = @($copies | Where-Object { $_.Missing -eq 0 } | Sort-Object { $_.File.LastWriteTimeUtc } -Descending)
$preferred = $null
if ($Prefer) {
  $preferred = $copies | Where-Object { $_.Account.Label -ieq $Prefer -or $_.Account.Command -ieq $Prefer } | Select-Object -First 1
  if (-not $preferred) { throw "-Prefer '$Prefer': there's no copy of this conversation there. It's in: $((@($copies | ForEach-Object { $_.Account.Label })) -join ', ')." }
}
if ($preferred) { $source = $preferred }
elseif ($complete) { $source = $complete[0] }
else {
  Write-Host ''
  Write-Host 'This conversation was continued in more than one place, so nothing was changed:' -ForegroundColor Yellow
  foreach ($c in @($copies | Where-Object { $_.Only -gt 0 })) {
    Write-Host ("  {0,-10} last used {1}, {2} typed message(s) only here" -f $c.Account.Label, $c.File.LastWriteTime.ToString('dd/MM HH:mm'), $c.Only)
  }
  Write-Host 'Choose the copy to continue from, for example:' -ForegroundColor Yellow
  $example = ($copies | Where-Object { $_.Only -gt 0 } | Sort-Object { $_.File.LastWriteTimeUtc } -Descending | Select-Object -First 1).Account.Label
  Write-Host "  claude-handoff -To $To -Session $($cliId.Substring(0, 8)) -Prefer $example"
  Write-Host 'The other copies are saved next to it as .diverged files first.' -ForegroundColor DarkGray
  exit 2
}

# --- Read the sidebar; stop if entries don't look the way this script expects --------------------------
$allEntries = @(foreach ($win in $windows) {
  foreach ($f in @(Get-ChildItem -LiteralPath $win.Sessions -Recurse -File -Filter 'local_*.json' -ErrorAction SilentlyContinue)) {
    $o = Read-Json $f.FullName
    if ($o) { [pscustomobject]@{ Window = $win; File = $f; Data = $o } }
  }
})
if ($targetWindows) {
  $wellFormed = @($allEntries | Where-Object { (Get-Prop $_.Data 'sessionId') -and (Get-Prop $_.Data 'cliSessionId') -and (Get-Prop $_.Data 'cwd') })
  if (-not $wellFormed) { throw "The app's sidebar entries don't look the way this script expects (an update may have changed them). Nothing was written." }
}
$known = @($allEntries | Where-Object { (Get-Prop $_.Data 'cliSessionId') -eq $cliId } |
           Sort-Object { [double](Get-Prop $_.Data 'lastActivityAt') } -Descending)
$src = if ($known) { $known[0].Data } else { $null }

$title = Get-Prop $src 'title'
if (-not $title -or ($genericTitles -contains $title)) { $title = $source.Info.Title }
$cwd = Get-Prop $src 'cwd'; if (-not $cwd) { $cwd = $Path }
$originCwd = Get-Prop $src 'originCwd'; if (-not $originCwd) { $originCwd = $cwd }
$createdAt = Get-Prop $src 'createdAt'
if (-not $createdAt -and $source.Info.Started) { try { $createdAt = ([DateTimeOffset]::Parse($source.Info.Started)).ToUnixTimeMilliseconds() } catch {} }
if (-not $createdAt) { $createdAt = Get-NowMs }
$model = Get-Prop $src 'model'; if (-not $model) { $model = $source.Info.Model }

Write-Host ''
Write-Host "$(if ($refresh) { 'Refreshing' } else { 'Handing off' }): $title" -ForegroundColor Cyan
Write-Host "  conversation $cliId  ($Path)" -ForegroundColor DarkGray
Write-Host "  to           $(Get-AccountName $targetAccount)" -ForegroundColor DarkGray
Write-Host "  latest copy  $($source.Account.Label)" -ForegroundColor DarkGray
Write-Host ''

if (-not $DryRun) { try { Install-Handoff $false } catch { Write-Host "  (Couldn't update the /handoff skill: $($_.Exception.Message))" -ForegroundColor Yellow } }

# --- Copy the conversation: to .claude for the desktop app, and to the CLI folders of the target account
# and of the account this runs in, so both sides of a handoff end up with the same copy ---------------------
$destinations = @($accounts | Where-Object { $_.Shared -or $_.AccountId -eq $targetAccount -or ($currentAccount -and $_.AccountId -eq $currentAccount) })
if ($preferred) { $destinations += @($copies | Where-Object { $_.Only -gt 0 } | ForEach-Object { $_.Account }) }
$seenRoots = @{}
foreach ($d in $destinations) {
  if ($seenRoots.ContainsKey($d.Root)) { continue }
  $seenRoots[$d.Root] = $true
  $line = "  {0,-20}" -f $(if ($d.Shared) { 'Conversations' } else { "CLI $($d.Command)" })
  if ($d.Root -eq $source.Account.Root) { Write-Host "$line already has the latest copy"; continue }

  $destDir = Join-Path $d.Root "projects\$projectKey"
  $dest = Join-Path $destDir "$cliId.jsonl"
  $existing = $copies | Where-Object { $_.Account.Root -eq $d.Root } | Select-Object -First 1
  if ($existing -and $existing.File.Length -eq $source.File.Length -and $existing.File.LastWriteTimeUtc -ge $source.File.LastWriteTimeUtc) {
    Write-Host "$line already up to date"; continue
  }
  # Only reachable with -Prefer: this copy has typed messages the chosen one lacks, so keep it before replacing it
  $lost = 0
  if ($existing) {
    $diff = [System.Collections.Generic.HashSet[string]]::new($existing.Info.Typed); $diff.ExceptWith($source.Info.Typed); $lost = $diff.Count
  }
  if ($DryRun) {
    $note = if ($lost) { " (saving its $lost other message(s) as a .diverged file first)" } else { '' }
    Write-Host "$line [dry run] would copy it$note"; continue
  }
  New-Item -ItemType Directory -Force -Path $destDir | Out-Null
  if ($lost) {
    $keep = "$dest.diverged-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item -LiteralPath $dest -Destination $keep -Force
    Write-Host "$line kept the old copy as $(Split-Path $keep -Leaf)" -ForegroundColor Yellow
  }
  Copy-Item -LiteralPath $source.File.FullName -Destination $dest -Force
  Copy-Tree (Join-Path $source.Dir $cliId) (Join-Path $destDir $cliId)                                 # subagents, tool results
  Copy-Tree (Join-Path $source.Account.Root "file-history\$cliId") (Join-Path $d.Root "file-history\$cliId")   # rewind checkpoints
  Write-Host "$line copied" -ForegroundColor Green
}

# --- Add or refresh the sidebar entry in each window the target account uses ---------------------------
$restart = @(); $open = @(); $later = @()
foreach ($win in $targetWindows) {
  $folder = Join-Path $win.Sessions "$targetAccount\$targetOrg"
  $signedIn = $win.LastAccount -eq $targetAccount
  $mine = @($known | Where-Object { $_.Window.Name -eq $win.Name -and $_.File.DirectoryName -eq $folder })
  $line = "  {0,-20}" -f "Sidebar $($win.Name)"

  if ($mine) {
    if ($win.Running) {
      Write-Host "$line already listed (window is open, so the entry was left as it is)"
    } elseif ($DryRun) {
      Write-Host "$line already listed [dry run] would move it to the top"
    } else {
      foreach ($m in $mine) {
        $text = Get-Content -LiteralPath $m.File.FullName -Raw -Encoding UTF8
        $text = [regex]::Replace($text, '("lastActivityAt"\s*:\s*)\d+', ('${1}' + (Get-NowMs)))
        $text = [regex]::Replace($text, '("isArchived"\s*:\s*)true', '${1}false')
        Write-Utf8 $m.File.FullName $text
      }
      Write-Host "$line already listed, moved to the top" -ForegroundColor Green
    }
  } else {
    # The app keys entries (and its "deleted" markers) by the id after "local_". If this conversation was
    # deleted from this account before, a marker blocks that id, so the new entry gets an id of its own.
    $entryId = $cliId
    if ((Test-Path -LiteralPath (Join-Path $folder "deleted_$entryId")) -or (Test-Path -LiteralPath (Join-Path $folder "local_$entryId.json"))) {
      $entryId = [guid]::NewGuid().ToString()
    }
    $now = Get-NowMs
    $entry = [ordered]@{
      sessionId = "local_$entryId"; cliSessionId = $cliId; cwd = $cwd; originCwd = $originCwd
      createdAt = [long]$createdAt; lastActivityAt = $now; indexedAt = $now
    }
    if ($model) { $entry.model = $model }
    $entry.isArchived = $false; $entry.title = $title; $entry.titleSource = 'auto'; $entry.permissionMode = 'default'
    $entry.alwaysAllowedReasons = @(); $entry.sessionPermissionUpdates = @()
    $entry.adoptedFromOtherSurface = $true; $entry.fromCliTranscript = $true
    if ($DryRun) {
      Write-Host "$line [dry run] would add it"
    } else {
      New-Item -ItemType Directory -Force -Path $folder | Out-Null
      Write-Utf8 (Join-Path $folder "local_$entryId.json") ($entry | ConvertTo-Json -Depth 5)
      Write-Host "$line added" -ForegroundColor Green
    }
  }
  if (-not $signedIn) { $later += $win } elseif ($win.Running) { $restart += $win } else { $open += $win }
}

# --- What to do next -----------------------------------------------------------------------------------
if ($DryRun) { Write-Host ''; Write-Host 'Dry run: nothing was written.' -ForegroundColor Yellow; exit 0 }
$project = Split-Path $cwd -Leaf
$cliTargets = @($accounts | Where-Object { $_.AccountId -eq $targetAccount -and -not $_.Shared })
Write-Host ''
if ($refresh) {
  $places = @(@($targetWindows | Where-Object { $_.LastAccount -eq $targetAccount } | ForEach-Object { $_.Title }) + @($cliTargets | ForEach-Object { $_.Command }))
  Write-Host "In sync: $($places -join ', ') now have this conversation as it is here." -ForegroundColor Green
  Write-Host '  You can keep going here. To switch to one of the others, stop sending messages here first:'
  foreach ($win in $restart) { Write-Host "  - $($win.Title) is open: quit it completely (system tray icon > Quit), open it again, and open '$title'." }
  foreach ($win in $open) { Write-Host "  - Open $($win.Title) and, in the sidebar under '$project', open '$title'." }
  foreach ($a in $cliTargets) { Write-Host "  - In a terminal, in $($Path): run $($a.Command), then /resume." }
  Write-Host '  Messages sent after this refresh are only here: refresh again before switching.' -ForegroundColor DarkGray
  exit 0
}
Write-Host 'Next:' -ForegroundColor Green
Write-Host '  1. Stop here: send no more messages to this conversation where you are now.'
$n = 2
if ($restart -or $open) {
  foreach ($win in $restart) { Write-Host "  $n. $($win.Title) is open: quit it completely (system tray icon > Quit) and open it again."; $n++ }
  foreach ($win in $open) { Write-Host "  $n. Open $($win.Title)."; $n++ }
  Write-Host "  $n. In the sidebar, under '$project', open '$title' and carry on."; $n++
}
foreach ($a in $cliTargets) {
  $lead = if ($restart -or $open) { 'Or in a terminal' } else { "$n. In a terminal" }
  Write-Host "  $lead, in $($Path): run $($a.Command), then /resume."
}
foreach ($win in $later) {
  Write-Host "  (It will also be listed in $($win.Title) whenever you sign in there as $(Get-AccountName $targetAccount).)" -ForegroundColor DarkGray
}
Write-Host '  Desktop and each CLI keep separate copies: hand it off again whenever you switch between them.' -ForegroundColor DarkGray
exit 0
