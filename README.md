# Mobotix Timelapse Scripts

## Mobotix.ps1
Rename Mobotix files from the format /[IP]/xxx/xxx/Xxxxxx.jpg to /[Serial]/[Date]/[Date_Time].jpg
Further it can optimize (remove the MxPEG extension) and add an Exif tag.

| Parameter   | Description                                            | Default      |
| ----------- | ------------------------------------------------------ | ------------ |
| Source *    | Location of Mobotix files                              |              |
| Destination | Copy files here                                        | Rename Source|
| After       | Start after this datetime                              |              |
| Before      | Stop on this datetime                                  |              |
| FileFilter  | Search for this files (use *.jpg to process all images)| ??????.jpg   |
| Optimize¹   | Use jpegoptim to reduce file size                      | false        |
| Recommended | Optimize + Rename + WriteExif                          | false        |
| Rename      | Rename files to Date_Time                              | false        |
| SortBySerial| Add camera serial to path                              | false        |
| UpdateExif² | Update (and write) Exif information on all images      | false        |
| WriteExif²  | Write Exif information only when missing               | false        |

(*) Mandatory
(1) https://github.com/tjko/jpegoptim/releases
(2) https://exiftool.org/ 

## Check.ps1
Search for files near the full minute and the half minute, delete other images.

| Parameter | Description                                   | Default |
| --------- | --------------------------------------------- | ------- |
| Source *  | Location of renamed Mobotix files             |         |
| DryRun    | Don't touch files                             | false   |
| Delete    | Delete files except full minue and half minute| false   |

(*) Mandatory

## Timelapse.ps1
Create a timelapse.

| Parameter  | Description                                              | Default |
| ---------- | -------------------------------------------------------- | ------- |
| Source¹ *  | Location of renamed Mobotix files                        |         |
| AR         | Set aspect ratio, 0 (unchanged)                          | 0       |
| Bitrate    | Use bitrate instead of quality                           |         |
| CropImage  | Crop image (not implemented)                             | false   |
| Deflicker² | Deflicker images first                                   | false   |
| Denoise    | Use denoise filter, 0 (disabled) ... 65535               | 0       |
| Destination| Change default destination                               |         |
| Filter     | Create video from these files. Presets: Day (only daytime), 1day (1 image per day), 2day, 3day | .*-0.{2}\.jpg' |
| FPS        | Create video with this fps                               | 24      |
| Mode       | Daily (one video per day), All (one video from all days) | Daily   |
| Quality    | Quality of video, 0 (lossless) ... 51 (bad)              | 23      |
| SelectImage| Choose image on Mobotix two image files                  | Both    |
| Zoom       | Zoom video                                               | 1       |

(*) Mandatory
(1) https://github.com/BtbN/FFmpeg-Builds/releases
(2) https://github.com/struffel/simple-deflicker
