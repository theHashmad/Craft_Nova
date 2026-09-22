$root = "C:\Hashmad_ali\medtronic-automation-flaui-POC\CRAFT_NOVA"
Set-Location $root
Get-ChildItem -Recurse -Filter *.robot | ForEach-Object {
  $file = $_.FullName
  $dir = Split-Path $file
  $lines = Select-String -Path $file -Pattern '^\s*Resource\s+(.*)'
  foreach ($m in $lines) {
    $resource = $m.Matches[0].Groups[1].Value.Trim()
    $resource = $resource -replace '\s+.*$',''
    $resource = $resource.Trim()
    if ($resource.Length -ge 2) {
      if ( ($resource.StartsWith("'") -and $resource.EndsWith("'")) -or ($resource.StartsWith('"') -and $resource.EndsWith('"')) ) {
        $resource = $resource.Substring(1, $resource.Length - 2)
      }
    }
    $join = Join-Path $dir $resource
    if (Test-Path $join) {
      $p = (Resolve-Path $join).Path
      Write-Output ('OK|' + $file + '|' + $resource + '|' + $p)
    } else {
      Write-Output ('MISSING|' + $file + '|' + $resource + '|' + $join)
    }
  }
}
