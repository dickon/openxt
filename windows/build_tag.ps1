param (
  [string]$site,
  [string]$builddirectory,
  [string]$user,
  [string]$branch,
  [string]$certname,
  [string]$buildtype="openxtwin",
  [string]$gitbin="C:\Program Files\Git\bin\git.exe",
  [string]$pythonbin="C:\Python27\python.exe"
)

$mywd = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = ([System.IO.Directory]::GetCurrentDirectory())
. ($mywd + "\BuildSupport\winbuild-utils.ps1")
Import-Module $mywd\BuildSupport\invoke.psm1

Write-Host "Site $site build directory $builddirectory user $user gitbin [$gitbin]"
$repos=$builddirectory+"\openxt-replica"
Push-Location $builddirectory

if (! (Test-Path scripts)) {
  Invoke-CommandChecked "clone scripts" $gitbin clone https://github.com/dickon/scripts.git 
}

Invoke-CommandChecked "replicate github" $pythonbin scripts\replicate_github.py openxt $repos --user $user --git-binary $gitbin

if (! (Test-Path build-machines)) {
  Invoke-CommandChecked "clone build-machines" $gitbin clone https://github.com/dickon/build-machines.git 
}

$tagnum = & $pythonbin build-machines\do_tag.py -b $branch -r $repos $site-$buildtype- -i openxt -t -f --git-binary $gitbin -n windows/repositories.txt

if ($LastExitCode -ne 0) {
  throw "Unable to tag code $LastExitCode out $tagnum"
}

$tag = $site+"-"+$buildtype+"-"+$tagnum+"-"+$branch

Write-Host "Tag $tag"
Invoke-CommandChecked "clone openx for tag" $gitbin clone ($repos+'/openxt.git') openxt-$tag
Push-Location openxt-$tag\windows
Invoke-CommandChecked "checkout tag" $gitbin checkout $tag
Invoke-CommandChecked "winbuild prepare" powershell .\winbuild-prepare.ps1 tag=$tag config=sample-config.xml build=$tagnum certname=$certname giturl=$repos build=$tagnum gitbin=$gitbin
Invoke-CommandChecked "winbuild all" powershell .\winbuild-all.ps1

