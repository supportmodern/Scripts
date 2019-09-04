#Specify ISO Source location

$FoD_Source = "$env:USERPROFILE\Downloads\W10RSAT_FOD\1903\1903_FoD_Disk1.iso"

#Mount ISO

Mount-DiskImage -ImagePath "$FoD_Source"

$path = (Get-DiskImage "$FoD_Source" | Get-Volume).DriveLetter

#Language desired

$lang = "en-US"

#RSAT folder 

$dest = New-Item -ItemType Directory -Path "$env:SystemDrive\temp\RSAT_1903_$lang" -force

#get RSAT files 

Get-ChildItem ($path+":\") -name -recurse -include *~amd64~~.cab,*~wow64~~.cab,*~amd64~$lang~.cab,*~wow64~$lang~.cab -exclude *languagefeatures*,*Holographic*,*NetFx3*,*OpenSSH*,*Msix* |
ForEach-Object {copy-item -Path ($path+":\"+$_) -Destination $dest.FullName -Force -Container}

#get metadata

copy-item ($path+":\metadata") -Destination $dest.FullName -Recurse

copy-item ($path +":\"+"FoDMetadata_Client.cab") -Destination $dest.FullName -Force -Container

#Dismount ISO

Dismount-DiskImage -ImagePath "$FOD_Source"
