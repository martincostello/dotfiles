#! /usr/bin/pwsh

function Get-Default-Git-Branch() {
    param()
    return (git remote show origin | Select-String "HEAD branch: " -Raw).Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)[2].Trim()
}

function Remove-Git-Nondefault-Branches() {
    param([string]$DefaultBranch = "")

    if ([string]::IsNullOrWhiteSpace($DefaultBranch)) {
        $DefaultBranch = Get-Default-Git-Branch
    }

    git branch | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne $DefaultBranch } | Where-Object { $_ -ne ('* ' + $DefaultBranch) } | ForEach-Object { git branch -D $_ }
}

function Sync-With-Git-Upstream() {
    param([string]$DefaultBranch = "")

    if ([string]::IsNullOrWhiteSpace($DefaultBranch)) {
        $DefaultBranch = Get-Default-Git-Branch
    }

    $remotes = (git remote).Trim() -Split "\n"

    if ($remotes.Length -gt 1) {
        git checkout $DefaultBranch && git pull upstream $DefaultBranch && git push origin $DefaultBranch && git pull --prune && git submodule update --init --recursive
    } else {
        git checkout $DefaultBranch && git pull --prune
    }
}

function Get-Repo-Url() {
    return git config --get remote.origin.url
}

function Get-String-From-Url () {
    param([string]$Url)
    return (New-Object Net.WebClient).DownloadString($Url)
}

function Get-Fork-Url () {
    param([string]$RepoUrl)

    if (-Not $RepoUrl) {
        return $null
    }

    $url = [System.Uri]$RepoUrl

    if (-Not $Url) {
        throw "No URL for $RepoUrl"
    }

    $name = $url.PathAndQuery.Trim('/')
    $name = $name.TrimEnd('.git')

    $repo = gh api "repos/${name}" --hostname $url.Host | ConvertFrom-Json
    if (($repo.fork -eq $true) -And $repo.parent) {
        return $repo.parent.clone_url
    }

    return $null
}

function Clone-Fork () {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSUseApprovedVerbs", Scope="function", Target="_*", Justification = "Sensible verb.")]
    param([string]$RepoUrl)

    $url = [System.Uri]$RepoUrl
    $fullName = $url.PathAndQuery.Trim('/')
    $fullName = $fullName.TrimEnd('.git')
    $name = $fullName.Split('/')[1]

    git clone $RepoUrl && Push-Location $name

    $forkUrl = Get-Fork-Url -RepoUrl $RepoUrl
    if ($forkUrl) {
        git remote add upstream $forkUrl
    }

    if ($url.Host -eq "github.com") {
        git for-fun
    }

    git sync
}

New-Alias -Name git-tidy -Value Delete-Git-Nondefault-Branches
New-Alias -Name git-sync -Value Sync-With-Git-Upstream
New-Alias -Name git-clone-fork -Value Sync-With-Git-Upstream

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    dotnet complete --position $cursorPosition $wordToComplete | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

function GitW {
    $repoUrl = Get-Repo-Url
    if (-Not $repoUrl) {
        Write-Output "No git URL found"
        return
    }
    Start-Process chrome $repoUrl
}

Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS
}

Import-Module posh-git
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json" | Invoke-Expression

Invoke-Expression (&starship init powershell)
