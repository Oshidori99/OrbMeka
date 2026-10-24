# Tous les tests Godot, plusieurs à la fois (chacun a ses propres fichiers de test, ils ne se gênent pas).
# Depuis PowerShell, à la racine du projet :
#   .\tests\run_all.ps1                     tous les tests (avant chaque version)
#   .\tests\run_all.ps1 -Only fly,controls  seulement ceux-là (pendant le travail)
#   .\tests\run_all.ps1 -Jobs 2             nombre de tests en même temps (4 par défaut)
# Sécurité mémoire (PC planté le 24.10.2026, mémoire à 99 %) :
#   - au-dessus de MaxMemoryPercent (85 %) de mémoire utilisée, aucun nouveau test ne démarre ;
#   - au-dessus d'AbortMemoryPercent (90 %), tous les tests sont arrêtés et le script s'arrête ;
#   - un test qui dépasse MaxTestMemoryMB (2 Go) est arrêté et compté en échec.
param(
	[string[]]$Only = @(),
	[int]$Jobs = 4,
	[int]$TimeoutSeconds = 180,
	[int]$MaxMemoryPercent = 85,
	[int]$AbortMemoryPercent = 90,
	[int]$MaxTestMemoryMB = 2048,
	[string]$Godot = 'C:\Users\Dev\Desktop\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
)
$ErrorActionPreference = 'Stop'

function Get-MemoryPercent {
	$os = Get-CimInstance Win32_OperatingSystem
	return [int](100 * (1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize))
}
$root = Split-Path -Parent $PSScriptRoot
$logs = Join-Path $env:TEMP ('orbmeka-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $logs | Out-Null
# Tests juridiques, toujours lancés : licences (Godot, sons, polices) et aucun autre jeu cité.
$ALWAYS = @('licences', 'public_launcher')
$tests = Get-ChildItem (Join-Path $root 'tests') -Filter '*_test.gd' | Sort-Object Name
if ($Only.Count -gt 0) {
	$wanted = $Only | ForEach-Object { ($_ -split ',') } | ForEach-Object { $_.Trim() -replace '_test(\.gd)?$', '' } | Where-Object { $_ }
	$wanted = @($wanted) + $ALWAYS
	$tests = $tests | Where-Object { $wanted -contains ($_.BaseName -replace '_test$', '') }
}
$started = Get-Date
$queue = [System.Collections.Queue]::new(@($tests))
$running = @()
$results = @()
$aborted = $false
while ($queue.Count -gt 0 -or $running.Count -gt 0) {
	$memory = Get-MemoryPercent
	if ($memory -ge $AbortMemoryPercent) {
		foreach ($item in $running) { if (-not $item.Process.HasExited) { $item.Process.Kill() } }
		"ARRÊT : mémoire du PC à $memory % (limite $AbortMemoryPercent %). Tests arrêtés pour protéger le PC."
		"Fermez des programmes ou relancez avec moins de tests à la fois : .\tests\run_all.ps1 -Jobs 2"
		$aborted = $true
		break
	}
	while ($queue.Count -gt 0 -and $running.Count -lt $Jobs -and $memory -lt $MaxMemoryPercent) {
		$test = $queue.Dequeue()
		$out = Join-Path $logs ($test.BaseName + '.out.txt')
		$err = Join-Path $logs ($test.BaseName + '.err.txt')
		$process = Start-Process -FilePath $Godot -ArgumentList '--headless', '--path', "`"$root`"", '--script', "res://tests/$($test.Name)" -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
		$null = $process.Handle
		$running += [pscustomobject]@{ Test = $test; Process = $process; Out = $out; Err = $err; Start = Get-Date }
	}
	Start-Sleep -Milliseconds 200
	foreach ($item in @($running)) {
		$timedOut = ((Get-Date) - $item.Start).TotalSeconds -gt $TimeoutSeconds
		$tooBig = $false
		if (-not $item.Process.HasExited) {
			try { $item.Process.Refresh(); $tooBig = $item.Process.WorkingSet64 -gt ($MaxTestMemoryMB * 1MB) } catch {}
		}
		if ($item.Process.HasExited -or $timedOut -or $tooBig) {
			if (($timedOut -or $tooBig) -and -not $item.Process.HasExited) { $item.Process.Kill() }
			$text = ((Get-Content $item.Out, $item.Err -Raw -ErrorAction SilentlyContinue) -join '')
			$ok = (-not $timedOut) -and (-not $tooBig) -and $item.Process.ExitCode -eq 0 -and $text -notmatch 'FAIL:|SCRIPT ERROR|Parser Error'
			$detail = if ($tooBig) { "TROP DE MÉMOIRE (plus de $MaxTestMemoryMB Mo)" } elseif ($timedOut) { 'TROP LONG' } else { (($text -split "`n") | Where-Object { $_ -match 'FAIL:|SCRIPT ERROR|Parse' } | Select-Object -First 6) -join "`n" }
			$results += [pscustomobject]@{ Name = $item.Test.Name; Ok = $ok; Detail = $detail }
			$running = @($running | Where-Object { $_ -ne $item })
		}
	}
}
$failed = @($results | Where-Object { -not $_.Ok })
foreach ($result in $failed) { "ÉCHEC $($result.Name)"; $result.Detail }
$seconds = [int]((Get-Date) - $started).TotalSeconds
"Tests : $($results.Count - $failed.Count) / $($results.Count) réussis en $seconds s."
Remove-Item -Recurse -Force $logs -ErrorAction SilentlyContinue
if ($aborted -or $failed.Count -gt 0) { exit 1 }
exit 0
