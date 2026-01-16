param (
    [parameter(Mandatory=$True)][String]$Source,
    [Switch]$DryRun,
    [Switch]$Delete
)

$DeleteFiles = @()
$RenameFiles = @()
$info = 0

Get-ChildItem -Path $Source -Directory | Sort-Object FullName | ForEach-Object {
    Write-Host 'Source' $_.FullName
    $Path = $_.FullName
    $Date = $_.Name

    0..23 | ForEach-Object {
        $h = $_.ToString().PadLeft(2,'0')
        0..59 | ForEach-Object {
            $m = $_.ToString().PadLeft(2,'0')
            $filter = "$($Date)_*$h-$m"

            $min = Get-ChildItem -Path $Path -Filter "$filter-???.jpg" | Sort-Object -Property Name -Descending
            $a = @(0..5)
            0..5 | ForEach-Object {
                $a[$_] = $min | Where-Object Name -Like "$filter-$($_.ToString())??.jpg" | Select-Object -First 1
            }
            If (-Not($a[0] -And $a[3])) {
                Write-Host "Filter $filter*"
                $min
                $info = 2
                If(-Not($a[0])) {
                    Write-Host '0x missing'
                    If($a[1]) {
                        $a[0] = $a[1]
                        $RenameFiles += [PSCustomObject]@{
                            'Path' = $a[1].FullName
                            'NewName' = $a[1].DirectoryName + '\' + $a[1].BaseName + '_' + $h + '-' + $m + '-00C.jpg'
                        }
                    } ElseIf($m5) {
                        $a[0] = $m5
                        $DeleteFiles = $DeleteFiles | Where-Object Name -ne $m5.Name
                        $RenameFiles += [PSCustomObject]@{
                            'Path' = $m5.FullName
                            'NewName' = $m5.DirectoryName + '\' + $m5.BaseName + '_' + $h + '-' + $m + '-00C.jpg'
                        }
                    }
                }
                If(-Not($a[3])) {
                    Write-Host '3x missing'
                    If($a[4]) {
                        $a[3] = $a[4]
                        $RenameFiles += [PSCustomObject]@{
                            'Path' = $a[4].FullName
                            'NewName' = $a[4].DirectoryName + '\' + $a[4].BaseName + '_' + $h + '-' + $m + '-30C.jpg'
                        }
                    } ElseIf($a[2]) {
                        $a[3] = $a[2]
                        $RenameFiles += [PSCustomObject]@{
                            'Path' = $a[2].FullName
                            'NewName' = $a[2].DirectoryName + '\' + $a[2].BaseName + '_' + $h + '-' + $m + '-30C.jpg'
                        }
                    }
                }
            }
            $m5 = $a[5]

            If ($DeleteFiles) {
                If ($Delete) {
                    $DeleteFiles | Remove-Item
                } ElseIf ($DryRun -Or $info) {
                    Write-Host 'Would delete'
                    $DeleteFiles
                }
            }
            $DeleteFiles = $min | Where-Object Name -ne $a[0].Name
            $DeleteFiles = $DeleteFiles | Where-Object Name -ne $a[3].Name

            If ($RenameFiles) {
                If ($Delete) {
                    $RenameFiles | Rename-Item
                } ElseIf ($DryRun -Or $info) {
                    Write-Host 'Would rename'
                    $RenameFiles
                }
            }
            $RenameFiles = @()

            If ($info) {
                $info = $info - 1
            }
        }
    }
}