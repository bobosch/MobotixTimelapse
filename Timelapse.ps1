Param (
    [parameter(Mandatory=$True)][String]$Source,
    [Float]$AR = 0,
    [String]$Bitrate = "",
    [Switch]$CropImage = $false,
    [Switch]$Deflicker = $false,
    [Int]$Denoise = 0, # 0 (disabled) ... 65535
    [String]$Destination = '',
    [String]$Filter = '.*-0.{2}\.jpg',
    [Int]$FPS = 24,
    [ValidateSet("Daily", "All")]$Mode = 'Daily',
    [Int]$Quality = 23, # 0 (lossless) ... 51 (bad)
    [String]$SelectImage = 'Both',
    [Int]$Zoom = 1
)

$tmp = 'C:\Temp\Timelapse' + ((1..4 | Foreach-Object {'{0:x}' -f (Get-Random -Maximum 16)}) -join '')
$PathPrepared = "$tmp\Prepared"
$PathDeflickered = "$tmp\Deflickered"
$PathFileList = "$tmp\FileList.txt"

If (-not(Test-Path('.\ffmpeg.exe'))) {
    Write-Host 'Warning: ffmpeg not found. Download it from https://github.com/BtbN/FFmpeg-Builds/releases and copy it to the working directory'
    Break
}

If ($Deflicker -and -not(Test-Path('.\simple-deflicker.exe'))) {
    $Deflicker = $False
    Write-Host 'Warning: simple-deflicker not found. Download it from https://github.com/struffel/simple-deflicker and copy it to the working directory'
}

If ($Mode -ne 'Daily' -And $Filter -eq '.*-0.{2}\.jpg') {
    $Filter = '1day'
}

Switch ($Filter) {
    Day  {
        $Filter = '_(0[6-9]|1[0-8]).*-0.{2}\.jpg'
        $Mode = 'Daily'
    }
    1day {
        $Filter = '_12-00.*-0.{2}\.jpg'
        $Mode = 'All'
    }
    2day {
        $Filter = '_(09|14)-30.*-0.{2}\.jpg'
        $Mode = 'All'
    }
    3day {
        $Filter = '_(09|12|15)-00.*-0.{2}\.jpg'
        $Mode = 'All'
    }
}

If ($AR -Or $CropImage -Or $SelectImage -ne 'Both') {
    $PrepareImages = $true;
} else {
    $PrepareImages = $false
}

Add-Type -AssemblyName System.Drawing

Function GetFiles {
    Param (
        [String]$Path,
        [String]$Filter
    )

    Return Get-ChildItem -Path $Path -Recurse | Where-Object Name -Match $Filter
}

Function CreateFileList {
    Param (
        [String]$Path,
        [String]$Filter = '.*\.jpg'
    )

    $Lines = GetFiles -Path $Path -Filter $Filter | Select-Object @{name="FullName"; expression={"file '" + $_.FullName + "'"}} | Select-Object -ExpandProperty FullName
    [System.IO.File]::WriteAllLines($PathFileList, $Lines)
}

Function PrepareImage($File) {
    $Image = New-Object System.Drawing.Bitmap $File.FullName

    #AR > 2 -> Crop left image
    If($SelectImage -eq 'Left' -And ($Image.Width / $Image.Height) -gt 2) {
        Write-Host 'Two images -> Croping left image'
        $rect = New-Object System.Drawing.Rectangle(0, 0, ($Image.Width / 2), $Image.Height)
        $Image = $Image.Clone($rect, $Image.PixelFormat)
    }

    #6MP -> Crop Full sensor to visible size of lower resolution
    If($CropImage -And $Image.Width -eq 3072 -And $Image.Height -eq 2048) {
        Write-Host '6MP Sensor Image -> Crop to visible area'
        $rect = New-Object System.Drawing.Rectangle(222, 64, 2592, 1944)
        $Image = $Image.Clone($rect, $Image.PixelFormat)
    }

    #AR < 16:9 -> Crop height
    If($AR -ne 0) {
        If (($Image.Width / $Image.Height) -lt (16 / 9)) {
            Write-Host 'AR to low -> Croping height'
            $Height = $Image.Width / (16 / 9)
            $rect = New-Object System.Drawing.Rectangle(0, ($Image.Height - $Height), $Image.Width, $Height)
            $Image = $Image.Clone($rect, $Image.PixelFormat)
        }
    }

    $Image.Save($PathPrepared + '\' + $File.Name, [System.Drawing.Imaging.ImageFormat]::Jpeg)
}

Function CreateTimelapse {
    Param (
        [String]$Destination,
        [String]$Filter = '.*\.jpg',
        [String]$Location
    )

    New-Item -ItemType Directory -Path $tmp

    If ($PrepareImages) {
        New-Item -ItemType Directory -Path $PathPrepared
        GetFiles -Path $Location -Filter $Filter | ForEach-Object {
            PrepareImage $_
        }
        $Location = $PathPrepared
    }

    If ($Deflicker) {
        If ($Location -ne $PathPrepared) {
            New-Item -ItemType Directory -Path $PathPrepared
            GetFiles -Path $Location -Filter $Filter | ForEach-Object {
                Copy-Item -Path $_.FullName -Destination $PathPrepared
            }
        }

        New-Item -ItemType Directory -Path $PathDeflickered
        $Location = $PathDeflickered

        $params = @('-destination', $PathDeflickered, '-rollingAverage', 24, '-source', $PathPrepared)
        Write-Host "Deflicker: $params"
        & $PSScriptRoot\simple-deflicker.exe $params

        CreateFileList -Path $PathDeflickered
    } Else {
        CreateFileList -Path $Location -Filter $Filter
    }

    If ($Bitrate) {
        $params = @('-f', 'concat', '-safe', '0', '-i', $PathFileList, '-r', $FPS, '-c:v', 'libx264', '-b:v', $Bitrate, '-bufsize', $Bitrate, $Destination)
    } Else {
        $params = @('-f', 'concat', '-safe', '0', '-i', $PathFileList, '-r', $FPS, '-c:v', 'libx264', '-x264opts', "nr=$Denoise", '-crf', $Quality, $Destination)
    }
    Write-Host ""
    Write-Host "ffmpeg: $params"

    Set-Location $Location
    & $PSScriptRoot\ffmpeg.exe $params
    Set-Location $PSScriptRoot

    Remove-Item -Recurse $tmp
}

If ($Mode -eq 'Daily') {
    Get-ChildItem -Path $Source -Directory | Sort-Object FullName | ForEach-Object {
        Write-Host 'Source' $_.FullName
        If($Destination) {
            $Dest = $Destination + '\' + $_.Name + '.mkv'
        } Else {
            $Dest = $_.FullName + '.mkv'
        }
        If(Test-Path($Dest)) {
            Write-Host '  skipping'
        } Else {
            $Location = $_.FullName

#            $First = GetFiles -Path $Location -Filter $Filter | Select-Object -First 1
#            $Image = New-Object System.Drawing.Bitmap $First.FullName
#            $Scale = [String]$([math]::round($Image.Width / $Zoom)) + ':' + [String]$([math]::round($Image.Height / $Zoom))

            CreateTimelapse -Location $Location -Filter $Filter -Destination $Dest
        }
    }
} Else {
#    $Scale = '1920:1080' #HD

    If($Destination) {
        $Dest = $Destination + '\Timelapse.mkv'
    } Else {
        $Dest = $Source + '\Timelapse.mkv'
    }

    CreateTimelapse -Location $Source -Filter $Filter -Destination $Dest
}