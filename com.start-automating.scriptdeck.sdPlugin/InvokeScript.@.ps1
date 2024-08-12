# This file handles all InvokeScript related events

$invokeError = $null

$settings = $event.MessageData.payload.settings
if ($settings.ImagePath -and $event.SourceIdentifier -match "WillAppear") {
  Register-ButtonImageWatcher -ImagePath $settings.ImagePath -Context $event.MessageData.Context
  # set current image
  $eventFile = $settings.ImagePath -as [IO.FileInfo]
  if ($eventFile.Extension -in '.gif', '.svg' ,'.png', '.jpg', '.jpeg', '.bmp' -and $eventFile.Exists) {
    Send-StreamDeck -ImagePath $eventFile.Fullname -Context $event.MessageData.Context 
  }
}
elseif ($settings.ImagePath -and $event.SourceIdentifier -match "WillDisappear") {
  UnRegister-ButtonImageWatcher -Context $event.MessageData.Context
  # reset image to default
  Send-StreamDeck -EventName "setImage" -Context $event.MessageData.Context -payload @{target = 0; state = $settings.State}
}

foreach ($settingName in 'KeyDown','KeyUp','WillAppear', 'WillDisappear') {
    if ($event.SourceIdentifier -match $settingName -and
    $event.MessageData.payload.settings.$settingName) {
        $settingScript = $event.MessageData.payload.settings.$settingName
        Invoke-Expression $settingScript -ErrorAction Continue -ErrorVariable $invokeError
        if ($invokeError) {
            $invokeError | Out-string | Add-Content -Path $global:STREAMDECK_PLUGINLOGPATH
            Send-StreamDeck -ShowAlert -Context $event.MessageData.Context
    }
    elseif ($settings.ShowOKImage) {
            Send-StreamDeck -ShowOK -Context $event.MessageData.Context
        }
    }
}
