# Script to date stamp mp4 videos using FFmpeg
# Extracts the date in yyyy-mm-dd format from the creation time metadata
# Stamps the date to the bottom right corner of the video screen
# Outputs the video either to a subfolder or same folder with a prefix
# Samuel Riesterer
# 3/12/24

# --------------------------------------------------------------------------------------
# GLOBALS
# --------------------------------------------------------------------------------------
$folderPath = "D:\Videos\To be re-rendered\ToBeStamped" # Define the folder path where the MP4 files are located
$fontColor = "#FFFFFF" # Hex code of data stamp color
$fontType = "verdana" # Name of the ttf file found in C:\Windows\Fonts
$fontSize = 35
$xOffset = 100 # Pixel offset from the right of the screen
$yOffset = 50 # Pixel offset from the bottom of the screen
$outputToFolder = $true # Will output to a seperate folder if true
$outputFolder = "datestamped" # Name of folder for outputted files (subfolder of $folderPath)
$outputPrefix = "x" # Output files will be prefixed with this string if $outputToFolder is $false

# --------------------------------------------------------------------------------------

if ($outputToFolder -eq $true) {
	# Combine the folder path and the output folder name
	$outputFolderPath = Join-Path -Path $folderPath -ChildPath $outputFolder

	# Check if the output folder exists, if not, create it
	if (-not (Test-Path -Path $outputFolderPath -PathType Container)) {
		New-Item -Path $outputFolderPath -ItemType Directory
		}
	
	$logFilePath = Join-Path -Path $outputFolderPath -ChildPath "stamp_log.txt"
	}
else {
	$logFilePath = Join-Path -Path $folderPath -ChildPath "stamp_log.txt"
}	

# Delete the log file if it exists already
if (Test-Path -Path $logFilePath) {
    Remove-Item -Path $logFilePath -Force
    Write-Host "Existing log file deleted: $logFilePath"
}

try {
	# Iterate through each MP4 file in the folder
	Get-ChildItem -Path $folderPath -Filter *.mp4 | ForEach-Object {
		echo "==============================================================="

		$videoFilePath = $_.FullName
		
		if($outputToFolder -eq $false) {
			$skipMatch = -join("^", $outputPrefix)
			
			# Skip files whose filenames start with "x"
			if ($_.Name -match "^$skipMatch") {
				Write-Host "Skipping file $videoFilePath because its name starts with 'x'"
				continue
			}
		}
		
		# Run ffprobe and parse JSON output to extract creation date
		$jsonOutput = ffprobe -v quiet -print_format json -show_entries stream=index,codec_type:stream_tags=creation_time:format_tags=creation_time "$videoFilePath" | ConvertFrom-Json

		# Extract creation date from the JSON output
		$creationDate = $jsonOutput.streams[0].tags.creation_time.Substring(0,10)

		# Set the position and format of the timestamp
		$timestamp = -join("drawtext=fontfile=C\\:/Windows/fonts/", $fontType, ".ttf: text=", $creationDate, ": x=(w-tw-", $xOffset, "): y=(h-th-", $yOffset, "): fontcolor=", $fontColor, ": fontsize=", $fontSize, ": box=1: boxcolor=black@0.5: boxborderw=5")

		# Output file name
		if ($outputToFolder -eq $true) {
			$outputFilePath = "{0}\{1}.mp4" -f $outputFolderPath, $_.BaseName
		}
		else {
			$outputFilePath = "{0}\{1}{2}.mp4" -f $folderPath, $outputPrefix, $_.BaseName
		}

		# Add timestamp to the video
		& ffmpeg -i "$videoFilePath" -vf $timestamp -c:a copy -y "$outputFilePath"

		Write-Host "Timestamp added to $videoFilePath to $outputFilePath"
		
	
		"$(Get-Date) : Timestamp added to ${videoFilePath} : Output = ${outputFilePath}" | Out-File -FilePath $logFilePath -Append
	}

} catch {
    $_ | Out-File -FilePath $logFilePath -Append
}