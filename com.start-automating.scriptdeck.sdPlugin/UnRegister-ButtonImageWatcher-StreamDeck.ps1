function UnRegister-ButtonImageWatcher {
  <# 
  .SYNOPSIS
  Unregisters a button image watcher. 
  .DESCRIPTION
  Unregisters a file system watcher for the given file path and updates the Stream Deck button image when the file changes.
  #>
  param(
    [string]$Context
  )

  $fileChangedSourceId = "FileChanged_$Context"

  # Unregister all of the events subscribers related to this button.
  Get-EventSubscriber -SourceIdentifier $fileChangedSourceId -ErrorAction Ignore | Unregister-Event
}