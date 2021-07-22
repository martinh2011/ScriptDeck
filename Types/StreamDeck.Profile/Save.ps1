﻿$streamdeckprocess = Get-Process streamdeck -ErrorAction SilentlyContinue
$streamDeckPath    = "$($streamdeckprocess.Path)"
if ($streamDeckPath) { 
    Start-Process -FilePath $streamDeckPath -ArgumentList '--quit' -Wait
}
#$streamdeckprocess | Stop-Process

foreach ($action in $this.Actions.psobject.properties) {
    $stateIndex = 0
    $actionImagePath  = $this.Path | 
        Split-Path | 
        Join-Path -ChildPath $action.Name |
        Join-Path -ChildPath CustomImages
    foreach ($state in $action.value.states) {
        
        if ($state.Image) {
            if ($state.Image -match '^http(?:s)?://') {
                $imageUri = [uri]$state.Image
                $fileName = $imageUri.Segments[-1]
                
                $destinationPath  =  Join-Path $actionImagePath $fileName
                if (-not (Test-Path $destinationPath)) {
                    $null = New-Item -ItemType File -Path $destinationPath -Force
                }
                [Net.Webclient]::new().DownloadFile($imageUri, $destinationPath)
                $state.image = $fileName
            }
            elseif ($state.Image.Contains([IO.Path]::DirectorySeparatorChar) -and 
                -not $state.Image.ToLower().StartsWith($this.Path.ToLower)
            ) {
                $resolvedImagePath  = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($state.Image)
                if (-not $resolvedImagePath) {
                    Write-Warning "Could not update image for $($action.Name)"
                    continue
                }
                $fileName = [IO.Path]::GetFileName("$resolvedImagePath")
                $destinationPath  =  Join-Path $actionImagePath $fileName
                if (-not (Test-Path $destinationPath)) {
                    $null = New-Item -ItemType File -Path $destinationPath -Force
                }
                Copy-Item -Path $resolvedImagePath -Destination $destinationPath -Force
                $state.Image = $fileName
            }
        }
        $stateIndex++
    }
}
$this |
    Select-Object -Property * -ExcludeProperty Path, GUID | 
    ConvertTo-Json -Depth 100 | 
    Set-Content -literalPath $this.Path -Encoding UTF8

if ($streamDeckPath) {
    $streamdeckprocess = Get-Process streamdeck -ErrorAction SilentlyContinue
    Register-ObjectEvent -InputObject $streamdeckProcess -EventName Exited -Action ([ScriptBlock]::Create(@"
Write-Verbose 'Process Exited, Starting a new one'
Start-Process '$($streamdeckprocess.Path)'
"@)) |Out-Null
    <#
    for ($tries =0; $tries -lt 6; $tries++) {
        Start-Sleep -Milliseconds 250
        
        $streamdeckprocess = Get-Process streamdeck -ErrorAction SilentlyContinue
        Write-Verbose "$streamdeckprocess " 
        if (-not $streamdeckprocess) {break }
        else {
            $streamDeckNewPath = "$($streamdeckprocess.Path)"
            Write-Verbose "$streamDeckNewPath "
        }
    }
    
    Start-Sleep -Seconds 2
    Write-Verbose "Starting $streamDeckNewPath"
    Start-Process $streamDeckNewPath -PassThru 2>&1
    #>
}
