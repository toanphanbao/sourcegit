[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$Output = "publish\win-x64",
    [string]$BuildRoot = ""
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$sourceProject = Join-Path $repoRoot "src\SourceGit.csproj"
$avaloniaEditTextMate = Join-Path $repoRoot "depends\AvaloniaEdit\src\AvaloniaEdit.TextMate\AvaloniaEdit.TextMate.csproj"
$absoluteOutput = Join-Path $repoRoot $Output

if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path $env:TEMP "sourcegit-build"
}

$absoluteBuildRoot = [System.IO.Path]::GetFullPath($BuildRoot)

if (-not (Test-Path $sourceProject)) {
    throw "Project file not found: $sourceProject"
}

if (-not (Test-Path $avaloniaEditTextMate)) {
    throw "Missing submodule content at '$avaloniaEditTextMate'. Run 'git submodule update --init --recursive' in the repository first."
}

$env:DOTNET_CLI_HOME = Join-Path $repoRoot ".dotnet-cli"
$env:NUGET_PACKAGES = Join-Path $repoRoot ".nuget\packages"
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
$env:LOCALAPPDATA = Join-Path $repoRoot ".localappdata"

New-Item -ItemType Directory -Force -Path $env:DOTNET_CLI_HOME, $env:NUGET_PACKAGES, $env:LOCALAPPDATA, $absoluteOutput, $absoluteBuildRoot | Out-Null

$badProxyValues = @(
    "http://127.0.0.1:9",
    "https://127.0.0.1:9",
    "http://localhost:9",
    "https://localhost:9"
)

foreach ($proxyVar in @("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")) {
    $proxyValue = [Environment]::GetEnvironmentVariable($proxyVar)
    if ($proxyValue -and $badProxyValues.Contains($proxyValue.Trim().ToLowerInvariant())) {
        Remove-Item "Env:$proxyVar" -ErrorAction SilentlyContinue
    }
}

$runningSourceGit = Get-Process -Name "SourceGit" -ErrorAction SilentlyContinue
if ($runningSourceGit) {
    $runningSourceGit | Stop-Process -Force

    foreach ($proc in $runningSourceGit) {
        try {
            $proc.WaitForExit(10000) | Out-Null
        }
        catch {
            # The process may already be fully terminated.
        }
    }
}

dotnet build-server shutdown | Out-Null

dotnet publish `
    -c $Configuration `
    -r $Runtime `
    -p:DisableAOT=true `
    -p:UsedAvaloniaProducts= `
    --artifacts-path $absoluteBuildRoot `
    -o $absoluteOutput `
    $sourceProject
