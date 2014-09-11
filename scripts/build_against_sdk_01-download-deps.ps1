$msg_prefix='====================== '

Try{

    Write-Output "$msg_prefix MAPNIK_VERSION: $env:MAPNIK_VERSION"
    $mapnik_remote='https://mapnik.s3.amazonaws.com/dist/dev/mapnik-win-sdk-' + $env:Platform + '-v2.2.0-1892-g2b5b573.7z'
    $mapnik_local="$env:DL_DIR\mapnik-sdk.7z"
    $mapnik_unpacked="$env:MAPNIK_DIR"

    ###CREATE DOWNLOAD DIR
    if(!(Test-Path -Path $env:DL_DIR )){
    	Write-Output "$msg_prefix creating download directory: $env:DL_DIR"
	    New-Item -ItemType directory -Path $env:DL_DIR
    } else {
    	Write-Output "$msg_prefix download directory exists already: $env:DL_DIR"
    }

	###DOWNLOAD DEPENDENCIES
	if(!(Test-Path -Path $mapnik_local )){
        Write-Output "$msg_prefix downloading dependencies $msg_prefix"
    	Write-Output "$msg_prefix downloading mapnik sdk: $mapnik_remote"
    	(new-object net.webclient).DownloadFile($mapnik_remote, $mapnik_local)
    } else {
        Write-Output "$msg_prefix using cached $mapnik_local"
    }

	Write-Output "$msg_prefix dependencies downloaded $msg_prefix"

	if(!(Test-Path -Path $mapnik_unpacked )){
	   ###EXTRACT DEPENDENCIES
	   ##7z does not have a silent mode -> pipe to FIND to reduce ouput
	   ##| FIND /V "ing  "
	   Write-Output "$msg_prefix extracting mapnik sdk: $mapnik_unpacked"
  	   invoke-expression "& 7z -y x $mapnik_local | FIND /V `"ing  `""
    } else {
        Write-Output "$msg_prefix using cached $mapnik_unpacked"
    }
    
}
Catch {
	Write-Output "`n`n$msg_prefix`n!!!!EXCEPTION!!!`n$msg_prefix`n`n"
	Write-Output "$_.Exception.Message`n"
	Exit 1
}
