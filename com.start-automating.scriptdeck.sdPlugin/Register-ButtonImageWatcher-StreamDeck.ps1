function Register-ButtonImageWatcher {
  <# 
  .SYNOPSIS
  Registers a button image watcher. 
  .DESCRIPTION
  Registers a file system watcher for the given file path and updates the Stream Deck button image when the file changes.
  #>
  param(
    [string]$ImagePath,
    [string]$Context
  )

  $FolderToWatch = $ImagePath | Split-Path -Parent
  if (-not (Test-Path $FolderToWatch)) {
    throw "The folder '$FolderToWatch' does not exist."
  }
  $ImageFileToWatch = $ImagePath | Split-Path -Leaf


  # Create a FileSystemWatcher
  $fileSystemWatcher = [IO.FileSystemWatcher]::new()
  $fileSystemWatcher | Add-Member SourceEvent $event -Force
  $fileSystemWatcher.Path = $FolderToWatch
  $fileSystemWatcher.Filter = $ImageFileToWatch
  $fileSystemWatcher.NotifyFilter = 'LastWrite'

  # predetermine the event id
  $fileChangedSourceId = "FileChanged_$($event.MessageData.Context)"
  # and create a handler to propagate the event.
  $propagateFileEvent = "
      `$fileChangedContext  = '$($event.MessageData.Context)'
      `$fileChangedSourceId = '$fileChangedSourceId'
  " + {
      # Why not subscribe directly?
      # FileSystemWatcher often sends multiple events,
      # so we'll guard against that by propagating only the first in a timeframe.
      if ($script:LastFileEvent) {
          if (($event.TimeGenerated - $script:LastFileEvent.TimeGenerated) -gt '00:00:00.25') {
              $script:LastFileEvent = $null
          }
      }

      # If the last event was from the same context, return
      if ($script:LastFileEvent -and $event.SourceArgs[1].FullPath -eq $script:LastFileEvent.SourceArgs[1].FullPath -and
          ($script:LastFileEvent.MessageData.Context -eq $event.MessageData.Context)) {
          return
      }
      
      $script:LastFileEvent = $event

      # Create an object for the file change
      $eventMessageData = [Ordered]@{
          FilePath = $event.SourceArgs[1].FullPath
      }
      # and get the subscriber.
      $sourceSubscriber = Get-EventSubscriber | 
          Where-Object { $_.SourceObject.SourceEvent.MessageData.Context -eq $fileChangedContext }            
          
      # The subscriber has the source event, which provides additional context
      foreach ($prop in $sourceSubscriber.SourceObject.SourceEvent.MessageData.psobject.properties) {
          # so add that to the message.
          $eventMessageData[$prop.Name] = $prop.Value
      }

      $eventMessageData = [PSCustomObject]$eventMessageData
      # and generate the file event.
      New-Event -SourceIdentifier $fileChangedSourceId -MessageData $eventMessageData
  }

  # Now, we need to unregister all of the events subscribers related to this button.
  Get-EventSubscriber -SourceIdentifier $fileChangedSourceId -ErrorAction Ignore | Unregister-Event

  # and register our changed event.
  Register-ObjectEvent -EventName Changed -Action (
      [scriptblock]::Create($propagateFileEvent)
  ) -InputObject $fileSystemWatcher

  # register a handler that set the button image when the file changes.
  Register-EngineEvent -SourceIdentifier $fileChangedSourceId -Action {
    $eventFile = $event.MessageData.FilePath -as [IO.FileInfo]
    # will set the image if the event file is an image file.
    if ($eventFile.Extension -in '.gif', '.svg' ,'.png', '.jpg', '.jpeg', '.bmp' -and $eventFile.Exists) {
        Send-StreamDeck -ImagePath $eventFile.Fullname -Context $event.MessageData.Context
    }

    if (-not $eventFile.Exists) {
        Send-StreamDeck -EventName "setImage" -Context $event.MessageData.Context -payload @{target = 0; state = $event.MessageData.State}
    }
  }
}