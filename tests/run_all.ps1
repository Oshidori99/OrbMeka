# Tests choisis avec surveillance de la charge totale du PC. Suite complète seulement sur demande.
param(
 [string[]]$Only = @(),
 [ValidateRange(1,4)][int]$Jobs = 4,
 [int]$TimeoutSeconds = 180,
 [ValidateRange(1,85)][int]$MaxMemoryPercent = 80,
 [ValidateRange(1,85)][int]$AbortMemoryPercent = 85,
 [ValidateRange(1,85)][int]$AbortCpuPercent = 85,
 [int]$MaxTestMemoryMB = 2048,
 [string]$Godot = 'C:\Users\Dev\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
)
$ErrorActionPreference = 'Stop'
function Get-PCLoad {
 $osInfo = Get-CimInstance Win32_OperatingSystem
 $cpuInfo = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -Filter "Name='_Total'" -ErrorAction SilentlyContinue
 $cpuValue = $cpuInfo.PercentProcessorUtility
 if ($null -eq $cpuValue) {
  $cpuInfo = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'"
  $cpuValue = $cpuInfo.PercentProcessorTime
 }
 if ($null -eq $cpuValue -or $null -eq $osInfo.FreePhysicalMemory -or $osInfo.TotalVisibleMemorySize -le 0) { throw 'Surveillance CPU/mémoire indisponible : aucun test ne sera lancé.' }
 return @{ Memory = 100.0*(1-$osInfo.FreePhysicalMemory/$osInfo.TotalVisibleMemorySize); Cpu = [math]::Min(100.0,[double]$cpuValue) }
}
function Stop-OwnedTest($process) {
 # Uniquement les descendants du processus créé pour ce test, jamais les autres Godot/éditeurs.
 if ($process.HasExited) { return }
 $snapshot = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
 $ownedIds = @([int]$process.Id)
 for ($depth=0; $depth -lt 8; $depth++) {
  $children = @($snapshot | Where-Object { $ownedIds -contains [int]$_.ParentProcessId -and $ownedIds -notcontains [int]$_.ProcessId })
  if ($children.Count -eq 0) { break }
  $ownedIds += @($children | ForEach-Object { [int]$_.ProcessId })
 }
 [array]::Reverse($ownedIds)
 foreach ($ownedId in $ownedIds) { Stop-Process -Id $ownedId -Force -ErrorAction SilentlyContinue }
}
$mutex = [System.Threading.Mutex]::new($false,'Local\OrbMeka-TestRunner')
$locked = $false
$running = @()
$logs = $null
$exitResult = 1
try {
 try { $locked = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $locked = $true }
 if (-not $locked) { throw 'Une autre session de tests tourne déjà. Aucun nouveau test lancé.' }
 $root = Split-Path -Parent $PSScriptRoot
 $logs = Join-Path $env:TEMP ('orbmeka-tests-' + [guid]::NewGuid().ToString('N'))
 New-Item -ItemType Directory -Force $logs | Out-Null
 $tests = @(Get-ChildItem (Join-Path $root 'tests') -Filter '*_test.gd' | Sort-Object Name)
 if ($Only.Count -gt 0) {
  $wanted = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() -replace '_test(\.gd)?$', '' }) + @('licences','public_launcher')
  $unknown = @($wanted | Where-Object { $_ -notin @($tests | ForEach-Object { $_.BaseName -replace '_test$', '' }) })
  if ($unknown.Count -gt 0) { throw ('Test inconnu : ' + ($unknown -join ', ')) }
  $tests = @($tests | Where-Object { $wanted -contains ($_.BaseName -replace '_test$', '') })
 }
 $started = Get-Date
 $queue = [System.Collections.Queue]::new($tests)
 $results = @()
 $aborted = $false
 $peakCpu = 0.0
 $peakMemory = 0.0
 while ($queue.Count -gt 0 -or $running.Count -gt 0) {
  $load = Get-PCLoad
  $peakCpu = [math]::Max($peakCpu,$load.Cpu)
  $peakMemory = [math]::Max($peakMemory,$load.Memory)
  if ($load.Memory -gt $AbortMemoryPercent -or $load.Cpu -gt $AbortCpuPercent) {
   'ARRÊT : CPU {0:N1} %, mémoire {1:N1} % ; seuil 85 %. Seuls nos tests sont arrêtés.' -f $load.Cpu,$load.Memory
   $aborted = $true
   break
  }
  $limit = if ($load.Cpu -ge 70 -or $load.Memory -ge 75) { [math]::Min(2,$Jobs) } else { $Jobs }
  if ($running.Count -eq 0 -and $queue.Count -gt 0 -and $load.Memory -ge $MaxMemoryPercent) {
   'Tests non lancés : mémoire déjà élevée ({0:N1} %).' -f $load.Memory
   $aborted = $true
   break
  }
  while ($queue.Count -gt 0 -and $running.Count -lt $limit -and $load.Memory -lt $MaxMemoryPercent) {
   $test = $queue.Dequeue()
   $out = Join-Path $logs ($test.BaseName + '.out.txt')
   $err = Join-Path $logs ($test.BaseName + '.err.txt')
   $process = Start-Process -FilePath $Godot -ArgumentList '--headless','--path',('"'+$root+'"'),'--script',('res://tests/'+$test.Name) -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
   $null = $process.Handle
   $running += [pscustomobject]@{ Test=$test; Process=$process; Out=$out; Err=$err; Start=Get-Date }
  }
  Start-Sleep -Milliseconds 500
  foreach ($item in @($running)) {
   $timedOut = ((Get-Date)-$item.Start).TotalSeconds -gt $TimeoutSeconds
   $tooBig = $false
   if (-not $item.Process.HasExited) { $item.Process.Refresh(); $tooBig = $item.Process.WorkingSet64 -gt ($MaxTestMemoryMB*1MB) }
   $scriptFailed = (Get-Content $item.Err -Raw -ErrorAction SilentlyContinue) -match "SCRIPT ERROR|Parser Error|FAIL:"
   if ($item.Process.HasExited -or $timedOut -or $tooBig -or $scriptFailed) {
    if ($timedOut -or $tooBig -or $scriptFailed) { Stop-OwnedTest $item.Process; $item.Process.WaitForExit() }
    $text = ((Get-Content $item.Out,$item.Err -Raw -ErrorAction SilentlyContinue) -join '')
    $ok = (-not $timedOut) -and (-not $tooBig) -and $item.Process.ExitCode -eq 0 -and $text -notmatch 'FAIL:|SCRIPT ERROR|Parser Error'
    $detail = if ($tooBig) { 'TROP DE MÉMOIRE' } elseif ($timedOut) { 'TROP LONG' } else { (($text -split "`n") | Where-Object { $_ -match 'FAIL:|SCRIPT ERROR|Parse' } | Select-Object -First 8) -join "`n" }
    $results += [pscustomobject]@{ Name=$item.Test.Name; Ok=$ok; Detail=$detail }
    $running = @($running | Where-Object { $_ -ne $item })
   }
  }
 }
 $failed = @($results | Where-Object { -not $_.Ok })
 foreach ($result in $failed) { 'ÉCHEC ' + $result.Name; $result.Detail }
 'Tests : {0} / {1} réussis en {2:N0} s. Pics observés : CPU {3:N1} %, mémoire {4:N1} %.' -f ($results.Count-$failed.Count),$results.Count,((Get-Date)-$started).TotalSeconds,$peakCpu,$peakMemory
 if (-not $aborted -and $failed.Count -eq 0) { $exitResult = 0 }
} catch {
 Write-Output $_.Exception.Message
} finally {
 foreach ($item in @($running)) { Stop-OwnedTest $item.Process }
 if ($logs -and (Test-Path -LiteralPath $logs)) {
  $resolvedLogs = [System.IO.Path]::GetFullPath($logs)
  $temporaryRoot = [System.IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
  if ($resolvedLogs.StartsWith($temporaryRoot,[System.StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $resolvedLogs -Recurse -Force -ErrorAction SilentlyContinue }
 }
 if ($locked) { $mutex.ReleaseMutex() }
 $mutex.Dispose()
}
exit $exitResult
