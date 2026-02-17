param (
    [parameter(Mandatory=$True)][String]$Source,
    [String]$Destination,
    [DateTime]$After,
    [DateTime]$Before,
    [String]$FileFilter = '??????.jpg',
    [Switch]$Optimize,
    [Switch]$Recommended,
    [Switch]$Rename,
    [Switch]$SortBySerial,
    [Switch]$UpdateExif,
    [Switch]$WriteExif
)

If ($Recommended) {
    $Optimize = $True
    $Rename = $True
    $WriteExif = $True
}

If ($Optimize -and -not(Test-Path('.\jpegoptim.exe'))) {
    $Optimize = $False
    Write-Host 'Warning: jpegoptim not found. Download it from https://github.com/tjko/jpegoptim/releases and copy it to the working directory'
}

If (($UpdateExif -or $WriteExif) -and -not(Test-Path('.\exiftool.exe'))) {
    $UpdateExif = $False
    $WriteExif = $False
    Write-Host 'Warning: ExifTool not found. Download it from https://exiftool.org/ and copy it to the working directory'
}

Add-Type -AssemblyName System.Drawing

# exiftool.exe -TimeZone=+2:00 _DSC2745_pps.jpg
# https://craigforrester.com/posts/convert-times-between-time-zones-with-powershell/

function GetExifItem($Image,$ID) {
    Try {
        $Value = $Image.GetPropertyItem($ID).Value
    } Catch {
        $Value = $null
    }

	If ($Value -ne $null) {
    	$Value = [System.Text.Encoding]::Default.GetString($Value, 0, $Value.Length - 1)
	}

    Return $Value
}

function GetFileInformation($FileName) {
    $Image = New-Object System.Drawing.Bitmap -ArgumentList $FileName

    $Info = [PSCustomObject]@{
        'Status' = 'None'
        'DateTimeOriginal' = $null
        'ImageHeight' = $null
        'ImageWidth' = $null
        'Make' = $null
        'Model' = $null
        'Serial' = $null
        'Software' = $null
        'Timezone' = $null
        'Type' = $null
    }

    # Get Exif Information
    # Comment
    $Value = GetExifItem $Image 37510 
    If($Value) {
        # Mobotix
        If($Value.StartsWith('#:M1IMG')){
            $Info.Status = 'Mobotix'
            $List = $Value | ConvertFrom-Csv -Delimiter = -Header Name,Value
            $DAT = $List | Where-Object Name -eq 'DAT'
            $TIM = $List | Where-Object Name -eq 'TIM'
            If($DAT -and $TIM) {
                $Info.DateTimeOriginal = [DateTime]::ParseExact($DAT.Value + ' ' + $TIM.Value, 'yyyy-MM-dd HH:mm:ss.fff', $null)
            }
            $Info.ImageHeight = $List | Where-Object Name -eq 'YTO' | Select-Object -ExpandProperty Value
            $Info.ImageWidth = $List | Where-Object Name -eq 'XTO' | Select-Object -ExpandProperty Value
            $Info.Make = $List | Where-Object Name -eq 'PRD' | Select-Object -ExpandProperty Value
            $Info.Model = $List | Where-Object Name -eq 'CFL' | Select-Object -ExpandProperty Value
            $Info.Serial = $List | Where-Object Name -eq 'MAC' | Select-Object -ExpandProperty Value
            $Info.Software = $List | Where-Object Name -eq 'SWV' | Select-Object -ExpandProperty Value
            $Info.Timezone = $List | Where-Object Name -eq 'TZN' | Select-Object -ExpandProperty Value
            $Info.Type = $List | Where-Object Name -eq 'IMT' | Select-Object -ExpandProperty Value # CLIP | IMAGE | EVENT
        }
    }
    # DateTimeOriginal
    $Value = GetExifItem $Image 36867
    If($Value) {
        If($Info.Status -ne 'Mobotix') {
	        $Info.DateTimeOriginal = [DateTime]::ParseExact($Value, 'yyyy:MM:dd HH:mm:ss', $null)
            # Serial
            $Info.Serial = GetExifItem $Image 42033
        }
        $Info.Status = 'Exif'
    }

    $Image.Dispose()

    Return $Info
}

$Items = Get-ChildItem -Path $Source -Filter $FileFilter -Recurse | Sort-Object FullName

If($After) {
    Write-Host "After"
    $Pos = 0
    $Info = GetFileInformation($Items[$Pos].FullName)
    If($Info.DateTimeOriginal -gt $After) {
        $Step = 0
    } Else {
        $Step = $Items.Count
    }
    While($Step -gt 1) {
        $Step = [math]::floor($Step / 2)
        $Info = GetFileInformation($Items[$Pos].FullName)
        Write-Host "Pos $Pos Step $Step Taken $($Info.DateTimeOriginal)"
        If($Info.DateTimeOriginal -gt $After) {
            $Pos = $Pos - $Step
        } Else {
            $Pos = $Pos + $Step
        }
    }
    $Items = $Items[$Pos .. ($Items.Count - 1)]
}

If($Before) {
    Write-Host "Before"
    $Pos = $Items.Count - 1
    $Info = GetFileInformation($Items[$Pos].FullName)
    If($Info.DateTimeOriginal -lt $Before) {
        $Step = 0
    } Else {
        $Step = $Items.Count
    }
    While($Step -gt 1) {
        $Step = [math]::floor($Step / 2)
        $Info = GetFileInformation($Items[$Pos].FullName)
        Write-Host "Pos $Pos Step $Step Taken $($Info.DateTimeOriginal)"
        If($Info.DateTimeOriginal -lt $Before) {
            $Pos = $Pos + $Step
        } Else {
            $Pos = $Pos - $Step
        }
    }
    $Items = $Items[0 .. $Pos]
}

$Items | ForEach-Object {
    If($_.Name -ne 'INFO.jpg') {
        Write-Host 'Source' $_.FullName
        $Name = ''
        $Path = ''

        # Get destination path and name
        If($Rename -or $SortBySerial -or $UpdateExif -or $WriteExif) {
            $Info = GetFileInformation($_.FullName)
            $Taken = $Info.DateTimeOriginal
        } Else {
            $Taken = $null
        }
        If($Taken) {
            $Name = $_.Name
            # Type
            If($Info.Type) {
                If($Info.Type -eq 'EVENT') {
                    $Event = 'E'
                } Else {
                    $Event = 'M'
                }
            } Else {
                If($_.BaseName.StartsWith('E') -or $_.BaseName.EndsWith('E')) {
                    $Event = 'E'
                } Else {
                    $Event = 'M'
                }
            }
            # Timezone
            If($Info.Timezone -eq 'CEST') {
                $Taken = $Info.DateTimeOriginal.AddHours(-1)
            }
            # New path
            $Path = '\' + $Taken.ToString('yyyy-MM-dd') + '\'
            If($Rename) {
                $Name = $Taken.ToString('yyyy-MM-dd_HH-mm-ss') + $Event + '.jpg'
            } Else {
                $Path = $Path + $_.Directory.Name + '\'
            }
        } Else {
            $Path = $_.DirectoryName.Substring($Source.Length) + '\'
        }

        If($Path) {
            If($SortBySerial -And $Info.Serial) {
                $Path = '\' + $Info.Serial.Replace(':', '') + $Path
            }
            If($Destination) {
                $Path = $Destination + $Path
            } Else {
                $Path = $Source + $Path
            }
            $FullDest = $Path + $Name
            Write-Host " Destination $FullDest"

            If(-Not(Test-Path($FullDest)) -Or -Not($Destination)) {
                # Create directory
                If(-Not(Test-Path($Path))) {
                    Write-Host "  Create directory"
                    New-Item $Path -ItemType Directory
                }

                # Optimize or copy
                If($Optimize) {
                    Write-Host "  Optimize jpeg"
        	        $params = @(
                        $_.FullName,
#                        '--force',
                        '--preserve'
                    )
                    If ($Destination) {
                        $params += "--dest=$Path"
                    }
        	        & .\jpegoptim $params
                    If($Rename) {
                        $temp = $Path + $_.Name
                        Write-Host "  Rename file"
                        Rename-Item -Path $temp -NewName $Name
                    }
                } ElseIf ($Destination) {
                    Write-Host "  Copy file"
                    Copy-Item -Path $_.FullName -Destination $FullDest
                } ElseIf ($_.FullName -ne $FullDest) {
                    Write-Host "  Move file"
                    Move-Item -Path $_.FullName -Destination $FullDest
                } Else {
                    Write-Host "  Skipping (no change)"
                }

                # Update exif data
                If(($WriteExif -And $Info.Status -eq 'Mobotix') -or ($UpdateExif -And $Info.Status)) {
                    Write-Host "  Update exif data"
        	        $params = @(
                        $FullDest,
                        '-overwrite_original',
                        '-preserve',
                        "-DateTimeOriginal='$($Info.DateTimeOriginal.ToString('yyyy:MM:dd HH:mm:ss'))'",
                        "-ImageHeight=$($Info.ImageHeight)",
                        "-ImageWidth=$($Info.ImageWidth)",
                        "-Make=$($Info.Make)",
                        "-Model=$($Info.Model)",
                        "-SerialNumber=$($Info.Serial)",
                        "-Software=$($Info.Software)"
                    )
        	        & .\exiftool $params
                }
            } Else {
                Write-Host "  Skipping (file exists)"
            }
        } Else {
            Write-Host "  Skipping (config)"
        }
    }
}