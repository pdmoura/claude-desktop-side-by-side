<#
.SYNOPSIS
  claude-sync (EXPERIMENTAL): pick Claude Code conversations from the current folder
  and send them to another account, so you can continue them there.

.DESCRIPTION
  Part of Claude Desktop Side by Side - unofficial, not affiliated with Anthropic.
  https://github.com/pdmoura/claude-desktop-side-by-side

  Claude Code keeps each account's conversations in
    %USERPROFILE%\<account folder>\projects\<name of the project folder>
  e.g. .claude-work\projects\C--Users-me-Desktop-my-app
  This script lists the conversations of ONE project folder across all your
  accounts, lets you pick which ones to send and to which account, and copies the
  newest version there. Only the conversations you pick are copied. Files are
  copied as they are (never edited). Memory notes are never copied.

  Account folders are found automatically: .claude (the default; Claude Desktop's
  Code tab uses it) and every .claude-<name> folder (created by
  "claude-profile.ps1 -Install -Name <name> -Cli").

  Afterwards, in the same folder:
  - CLI: start the other account (e.g. claude-work) and type /resume.
  - Claude Desktop: Code tab > "Import Claude Code CLI Sessions..." (send it to "Desktop").

.EXAMPLE
  claude-sync                                  # menu: pick conversations, the account, copy or move

.EXAMPLE
  claude-sync -List                            # just show this folder's conversations

.EXAMPLE
  claude-sync -Select 1,3 -To Work             # no menu
  claude-sync -Select all -To Desktop,Personal
  claude-sync -Select 1 -To Personal -Move     # send it back and remove it from the other accounts

.EXAMPLE
  claude-sync -From "C:\old\path\to\project"   # moved a project? bring its conversations along

.NOTES
  Close the conversation in Claude before sending it.
  The newest copy always wins, so don't continue the same conversation in two
  accounts without sending it in between.
  Relies on how Claude Code currently stores conversations; an update could change that.
#>
param(
  [string]$Path = (Get-Location).ProviderPath,
  [string]$From,         # optional: take conversations from this (old) folder and bring them into -Path
  [string[]]$Select,     # numbers from the list (1,3), "all", or conversation ids. Asked if omitted.
  [string[]]$To,         # account names (e.g. Work, Personal, Desktop) or "all". Asked if omitted.
  [switch]$List,
  [switch]$DryRun,
  [switch]$Move,         # after copying, remove it from the other CLI accounts (to the Recycle Bin). Asked in the menu.
  # Account folders under %USERPROFILE% (or full paths). Default: .claude plus every .claude-<name> folder.
  [string[]]$Accounts
)

$ErrorActionPreference = 'Stop'

if (-not $Accounts) {
  $Accounts = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match '^\.claude(-[A-Za-z0-9_-]+)?$' } |
                Sort-Object { $_.Name -eq '.claude' }, Name |      # named accounts first, the default (.claude) last
                ForEach-Object { $_.Name })
  if (-not $Accounts) { Write-Host "No Claude Code account folders found in $env:USERPROFILE (.claude or .claude-<name>)." -ForegroundColor Yellow; exit 0 }
}

# Claude Code names each project folder after its path, with every non-alphanumeric character turned into "-"
function Get-ProjectKey([string]$p) { ([IO.Path]::GetFullPath($p).TrimEnd('\')) -replace '[^A-Za-z0-9]', '-' }

function Get-Label([string]$root) {
  $n = Split-Path $root -Leaf
  if ($n -eq '.claude') { return 'Desktop' }
  $s = $n -replace '^\.claude-?', ''
  if (-not $s) { return $n }
  $s.Substring(0, 1).ToUpper() + $s.Substring(1).ToLower()
}

# A readable name: a real title if the conversation has one, otherwise its first message
function Get-Title([string]$file, [string[]]$genericNames) {
  $title = $null; $first = $null
  foreach ($line in (Get-Content -LiteralPath $file -TotalCount 400 -Encoding UTF8)) {
    if ($line -match '^\{"type":"(custom-title|ai-title|summary)"') {
      try {
        $o = $line | ConvertFrom-Json
        $t = @($o.customTitle, $o.aiTitle, $o.summary) | Where-Object { $_ } | Select-Object -First 1
        if ($t -and ($genericNames -notcontains $t)) { $title = $t }   # skip titles that are just an account name (e.g. set with claude -n WORK)
      } catch {}
    } elseif (-not $first -and $line -match '"type":"user"') {
      try {
        $c = ($line | ConvertFrom-Json).message.content
        $texts = if ($c -is [string]) { @($c) } else { @($c | Where-Object { $_.type -eq 'text' } | ForEach-Object { $_.text }) }
        $first = $texts | Where-Object { $_ -and $_ -notmatch '^\s*<' } | Select-Object -First 1
      } catch {}
    }
  }
  $t = if ($title) { $title } elseif ($first) { $first } else { '(no messages)' }
  $t = ($t -replace '\s+', ' ').Trim()
  if ($t.Length -gt 60) { $t = $t.Substring(0, 57) + '...' }
  $t
}

function Copy-Newer([string]$from, [string]$to) {
  if (-not (Test-Path -LiteralPath $from)) { return }
  robocopy $from $to /E /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "Copy failed: $from -> $to (robocopy code $LASTEXITCODE)" }
}

# Turn "1,3", "2-4", "all" (or ids / names) into a list of items
function Resolve-Choice([string[]]$tokens, [object[]]$items, [scriptblock]$matchByName) {
  $picked = New-Object System.Collections.Generic.List[object]
  foreach ($tok in (($tokens -join ',') -split '[,\s]+' | Where-Object { $_ })) {
    if ($tok -ieq 'all' -or $tok -ieq 'a') { return $items }
    if ($tok -match '^(\d+)-(\d+)$') { foreach ($i in [int]$Matches[1]..[int]$Matches[2]) { if ($i -ge 1 -and $i -le $items.Count) { $picked.Add($items[$i - 1]) } }; continue }
    if ($tok -match '^\d+$') { $i = [int]$tok; if ($i -ge 1 -and $i -le $items.Count) { $picked.Add($items[$i - 1]); continue } }
    $hit = @($items | Where-Object { & $matchByName $_ $tok })
    if ($hit) { $hit | ForEach-Object { $picked.Add($_) } } else { Write-Host "  Ignored '$tok' (not in the list)" -ForegroundColor Yellow }
  }
  # De-duplicate by conversation id / account folder (Select-Object -Unique would treat all these objects as equal)
  $seen = @{}; $unique = @()
  foreach ($item in $picked) {
    $id = if ($item.PSObject.Properties['Id']) { $item.Id } else { $item.Root }
    if (-not $seen.ContainsKey($id)) { $seen[$id] = $true; $unique += $item }
  }
  $unique
}

# --- Accounts and conversations -------------------------------------------------
$Path = [IO.Path]::GetFullPath($Path).TrimEnd('\')
$key  = Get-ProjectKey $Path
$srcKey = if ($From) { Get-ProjectKey $From } else { $key }

$targets = @(foreach ($acc in $Accounts) {
  $root = if ([IO.Path]::IsPathRooted($acc)) { $acc } else { Join-Path $env:USERPROFILE $acc }
  if (Test-Path -LiteralPath $root) {
    [pscustomobject]@{ Label = Get-Label $root; Root = $root; Project = Join-Path $root "projects\$key"; Source = Join-Path $root "projects\$srcKey"; History = Join-Path $root 'file-history' }
  }
})
$generic = @($targets | ForEach-Object { $_.Label.ToUpper() })

$byId = @{}
foreach ($t in $targets) {
  if (-not (Test-Path -LiteralPath $t.Source)) { continue }
  foreach ($f in Get-ChildItem -LiteralPath $t.Source -Filter *.jsonl -File) {
    if (-not $byId.ContainsKey($f.BaseName)) { $byId[$f.BaseName] = New-Object System.Collections.Generic.List[object] }
    $byId[$f.BaseName].Add([pscustomobject]@{ Account = $t; File = $f })
  }
}
$listedPath = if ($From) { $From } else { $Path }
if (-not $byId.Count) { Write-Host "No Claude Code conversations found for: $listedPath" -ForegroundColor Yellow; exit 0 }

$conversations = @(foreach ($id in $byId.Keys) {
  $copies = @($byId[$id] | Sort-Object { $_.File.LastWriteTimeUtc } -Descending)
  $newest = $copies[0]
  [pscustomobject]@{
    Id     = $id
    Newest = $newest
    Where  = (@($copies | ForEach-Object { $_.Account.Label }) -join ', ')
    When   = $newest.File.LastWriteTime
    Title  = Get-Title $newest.File.FullName $generic
  }
}) | Sort-Object When -Descending
$conversations = @($conversations)

Write-Host ""
Write-Host "Conversations in $listedPath" -ForegroundColor Cyan
if ($From) { Write-Host "(they will be copied into $Path)" -ForegroundColor DarkGray }
Write-Host ("  {0,-3} {1,-12} {2,-34} {3}" -f '#', 'Last used', 'In', 'Conversation') -ForegroundColor DarkGray
for ($i = 0; $i -lt $conversations.Count; $i++) {
  $c = $conversations[$i]
  Write-Host ("  {0,-3} {1,-12} {2,-34} {3}" -f ($i + 1), $c.When.ToString('dd/MM HH:mm'), $c.Where, $c.Title)
}
if ($List) { exit 0 }

# --- What to send ----------------------------------------------------------------
if (-not $Select) {
  Write-Host ""
  $answer = Read-Host "Which conversations? (e.g. 1  or  1,3  or  all; Enter to cancel)"
  if (-not $answer.Trim()) { Write-Host "Cancelled."; exit 0 }
  $Select = @($answer)
}
$chosen = @(Resolve-Choice $Select $conversations { param($c, $tok) $c.Id -like "$tok*" })
if (-not $chosen) { Write-Host "Nothing selected." -ForegroundColor Yellow; exit 0 }

# --- Where to send it ------------------------------------------------------------
if (-not $To) {
  Write-Host ""
  Write-Host "Send to which account?"
  for ($i = 0; $i -lt $targets.Count; $i++) {
    $note = if ($targets[$i].Label -eq 'Desktop') { '  (Claude Desktop app)' } else { '' }
    Write-Host ("  {0}  {1}{2}" -f ($i + 1), $targets[$i].Label, $note)
  }
  Write-Host "  A  All of them"
  $answer = Read-Host "Account (e.g. 2  or  2,4  or  A)"
  if (-not $answer.Trim()) { Write-Host "Cancelled."; exit 0 }
  $To = @($answer)
  $menu = $true
}
$destinations = @(Resolve-Choice $To $targets { param($t, $tok) $t.Label -ieq $tok -or (Split-Path $t.Root -Leaf) -ieq $tok })
if (-not $destinations) { Write-Host "No account selected." -ForegroundColor Yellow; exit 0 }

if ($menu -and -not $Move) {
  Write-Host ""
  Write-Host "Copy or move?"
  Write-Host "  C  Copy  (it stays in the other accounts too)"
  Write-Host "  M  Move  (remove it from the other accounts afterwards; they go to the Recycle Bin)"
  $answer = Read-Host "C or M (Enter = C)"
  if ($answer.Trim() -match '^[Mm]') { $Move = [switch]$true }
}

$running = @(Get-CimInstance Win32_Process -Filter "Name='claude.exe'" -ErrorAction SilentlyContinue |
             Where-Object { $_.ExecutablePath -like '*\.local\bin\claude.exe' -or $_.ExecutablePath -like '*\claude-code\*\claude.exe' })
if ($running.Count) { Write-Host "`nNote: Claude is running. If it has one of these conversations open, close it first and run this again." -ForegroundColor Yellow }

# --- Copy --------------------------------------------------------------------------
Write-Host ""
foreach ($c in $chosen) {
  $src = $c.Newest
  foreach ($d in $destinations) {
    $line = "  {0,-45} -> {1,-9}" -f $c.Title.Substring(0, [Math]::Min(45, $c.Title.Length)), $d.Label
    if ($d.Root -eq $src.Account.Root -and -not $From) { Write-Host "$line already the newest copy"; continue }
    $destFile = Join-Path $d.Project "$($c.Id).jsonl"
    if ((Test-Path -LiteralPath $destFile) -and (Get-Item -LiteralPath $destFile).LastWriteTimeUtc -ge $src.File.LastWriteTimeUtc) {
      Write-Host "$line already up to date"; continue
    }
    if ($DryRun) { Write-Host "$line [dry run] would copy"; continue }
    New-Item -ItemType Directory -Force -Path $d.Project | Out-Null
    Copy-Item -LiteralPath $src.File.FullName -Destination $destFile -Force
    Copy-Newer (Join-Path $src.Account.Source $c.Id) (Join-Path $d.Project $c.Id)                     # subagent transcripts
    foreach ($t in $targets) { Copy-Newer (Join-Path $t.History $c.Id) (Join-Path $d.History $c.Id) }  # rewind checkpoints
    Write-Host "$line copied" -ForegroundColor Green
  }
}

# --- Move: remove the other copies ---------------------------------------------------
# Removes the conversation from every CLI account that isn't a destination (Recycle Bin, so it can be restored).
# Claude Desktop's copy (.claude) is left alone: delete it in the Desktop app so its list stays consistent.
if ($Move) {
  Add-Type -AssemblyName Microsoft.VisualBasic
  $recycle = {
    param([string]$p)
    if (Test-Path -LiteralPath $p -PathType Container) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($p, 'OnlyErrorDialogs', 'SendToRecycleBin') }
    elseif (Test-Path -LiteralPath $p) { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($p, 'OnlyErrorDialogs', 'SendToRecycleBin') }
  }
  $destRoots = @($destinations | ForEach-Object { $_.Root })
  $desktopKept = $false
  Write-Host ""
  foreach ($c in $chosen) {
    $missing = @($destinations | Where-Object { -not (Test-Path -LiteralPath (Join-Path $_.Project "$($c.Id).jsonl")) })
    if ($missing -and -not $DryRun) { Write-Host "  Not removing '$($c.Title)': it isn't in $($missing[0].Label) yet." -ForegroundColor Yellow; continue }
    foreach ($copy in $byId[$c.Id]) {
      $acct = $copy.Account
      if (($destRoots -contains $acct.Root) -and -not $From) { continue }                 # this is where it lives now
      if ($acct.Label -eq 'Desktop') { $desktopKept = $true; continue }
      $label = "  {0,-45} x  {1,-9}" -f $c.Title.Substring(0, [Math]::Min(45, $c.Title.Length)), $acct.Label
      if ($running.Count -and ((Get-Date) - $copy.File.LastWriteTime).TotalMinutes -lt 2) {
        Write-Host "$label kept: used in the last 2 minutes, it may still be open" -ForegroundColor Yellow; continue
      }
      if ($DryRun) { Write-Host "$label [dry run] would remove"; continue }
      & $recycle $copy.File.FullName
      & $recycle (Join-Path $acct.Source $c.Id)                                             # subagent transcripts
      if ($destRoots -notcontains $acct.Root) { & $recycle (Join-Path $acct.History $c.Id) } # rewind checkpoints
      Write-Host "$label removed (Recycle Bin)" -ForegroundColor DarkYellow
    }
  }
  if ($desktopKept) { Write-Host "  It's also in Claude Desktop: delete it in the app if you don't want it there." -ForegroundColor DarkGray }
}

if (-not $DryRun) {
  Write-Host ""
  Write-Host "Done. In this folder: start the other account and type /resume," -ForegroundColor Green
  Write-Host "or in Claude Desktop use Code tab > 'Import Claude Code CLI Sessions...'." -ForegroundColor Green
}
exit 0
