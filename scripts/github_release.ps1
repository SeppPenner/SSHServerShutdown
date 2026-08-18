<#
.SYNOPSIS
    Creates the GitHub release for a tag and attaches the installer to it.

.DESCRIPTION
    The installer is deliberately not tracked in this repository, it is published as an asset of
    the release that belongs to the tag. The token is read from the Windows Credential Manager
    through "git credential fill", the same store "git push" uses, so no token is kept in a file,
    passed on a command line or written to the console. Running the script twice for the same tag
    reuses the release and replaces the asset.

.PARAMETER Tag
    The tag of the release, three parts and without a "v" prefix, for example 1.0.8.

.PARAMETER AssetPath
    Path to the built installer.

.PARAMETER Notes
    Release notes. Defaults to the matching line from Changelog.md.

.EXAMPLE
    .\scripts\github_release.ps1 -Tag 1.0.8 -AssetPath .\Setup\SSHServerShutdown-Setup.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Tag,

    [Parameter(Mandatory = $true)]
    [string] $AssetPath,

    [string] $Notes
)

$ErrorActionPreference = 'Stop'

$repository = 'SeppPenner/SSHServerShutdown'
$repositoryRoot = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $AssetPath)) {
    throw "Asset not found: $AssetPath"
}

$credential = "protocol=https`nhost=github.com`n`n" | git credential fill
$tokenLine = $credential | Select-String -Pattern '^password='
if ($null -eq $tokenLine) {
    throw 'No GitHub credential found. Run "git fetch" once and enter a personal access token as the password.'
}

$token = $tokenLine.ToString().Split('=', 2)[1]
$headers = @{
    Authorization          = "Bearer $token"
    Accept                 = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
}

# Reuse an existing release so that a rerun only swaps the asset instead of failing.
$release = $null

try {
    $release = Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "https://api.github.com/repos/$repository/releases/tags/$Tag"
    Write-Output "Release for tag $Tag already exists, reusing it."
}
catch {
    if ([int]$_.Exception.Response.StatusCode -ne 404) {
        throw
    }
}

if ($null -eq $release) {
    if ([string]::IsNullOrWhiteSpace($Notes)) {
        $changelog = Join-Path $repositoryRoot 'Changelog.md'
        $pattern = '^\* \*\*Version ' + [regex]::Escape($Tag)
        $entry = Select-String -Path $changelog -Pattern $pattern | Select-Object -First 1

        if ($null -eq $entry) {
            throw "No Changelog.md entry found for $Tag. Add one or pass -Notes."
        }

        $Notes = $entry.Line
    }

    $body = @{
        tag_name   = $Tag
        name       = $Tag
        body       = $Notes
        draft      = $false
        prerelease = $false
    } | ConvertTo-Json

    $release = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
        -Uri "https://api.github.com/repos/$repository/releases" -Body $body
    Write-Output "Created release $Tag."
}

$assetName = Split-Path -Leaf $AssetPath

# GitHub refuses a second asset with the same name, so the old one has to go first.
foreach ($existingAsset in $release.assets) {
    if ($existingAsset.name -eq $assetName) {
        Invoke-RestMethod -Method Delete -Headers $headers -Uri $existingAsset.url | Out-Null
        Write-Output "Removed the previous $assetName from the release."
    }
}

$uploadUri = ($release.upload_url -replace '\{\?name,label\}', '') + "?name=$assetName"
$uploadedAsset = Invoke-RestMethod -Method Post -Headers $headers `
    -ContentType 'application/octet-stream' -Uri $uploadUri -InFile $AssetPath

Write-Output ("Uploaded {0} ({1:N1} MB)." -f $uploadedAsset.name, ($uploadedAsset.size / 1MB))
Write-Output $release.html_url
