# new-user-story.ps1
# Interactive helper to create a new User Story issue and ensure it connects to the Milestone & Project.
param (
    [string]$Title,
    [int]$Points = 3,
    [string]$Milestone = "M2: Environment Built & Attack Demonstrated",
    [string]$Assignee = "UiwAntHuynhCIS"
)

$repo = "bash-y/CIS_CapstoneProj_Swag01erload"

if (-not $Title) {
    Write-Host "=== Create a New User Story Issue ===" -ForegroundColor Cyan
    $Title = Read-Host "Enter User Story Title (e.g. 'US-14: Implement ModSecurity WAF rules')"
    $ptsInput = Read-Host "Enter Story Points (1, 2, 3, or 5) [Default: 3]"
    if ($ptsInput) { $Points = [int]$ptsInput }
    $Milestone = Read-Host "Enter Milestone (e.g. M1, M2, M3, M4) [Default: M2: Environment Built & Attack Demonstrated]"
    $Assignee = Read-Host "Enter Assignee (UiwAntHuynhCIS, bash-y, or joromanii) [Default: UiwAntHuynhCIS]"
}

$body = @"
## User Story ($Points pts)
**As a** team member, **I want to** accomplish $Title **so that** the café environment security is enhanced.

### Tasks
- [ ] Implement technical control / proof (Size: M, @$Assignee)
- [ ] Document evidence and screenshots in wiki (Size: S, @$Assignee)
- [ ] Add verification test case (Size: S, @$Assignee)
"@

Write-Host "Creating issue on GitHub ($repo)..." -ForegroundColor Yellow
$output = gh issue create --repo $repo --title "$Title" --body "$body" --milestone "$Milestone" --assignee "$Assignee" --label "user-story,points:$Points"

if ($LASTEXITCODE -eq 0) {
    Write-Host "Issue successfully created: $output" -ForegroundColor Green
    Write-Host "Use this in your commit message: $Title <issue-number>: <description>" -ForegroundColor Cyan
} else {
    Write-Host "Failed to create issue via gh CLI. Check authentication ($env:GH_TOKEN or 'gh auth login')." -ForegroundColor Red
}
