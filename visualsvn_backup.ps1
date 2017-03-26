#this script use to backupp all repositories of VisualSVN
#Author Le Ton Phat - letonphat1988@gmail.com

$REPOS_PATH =  "E:\Repositories"
$POSTFIX_NAME = get-date -format "yyyy.MM.dd.HHmmss"
$REVISION_DB = "Z:\repositories_list.txt"
$BACKUP_DRIVE = "Z:"
$BACKUP_PATH = "${BACKUP_DRIVE}\SVNBACKUP"
$IS_NETDRIVE = $True
$7ZIP = "C:\Program Files\7-Zip\7z.exe"
$KEEPFILES = 5
$LOG_FOLDER = "C:\log\"
$LOG_PATH = "${LOG_FOLDER}backup_svndata_$(get-date -format `"yyyyMMdd`").txt"
$debug = $True
$exit_status = 0
$report_msg = ""

function logMsg($output, $color)
{
    if ($color -eq $null) {$color = "white"}
    if (-NOT (Test-path $LOG_FOLDER)) {New-Item $LOG_FOLDER -type directory}
    #Define message output
    $msg = "$(get-date -format `"dd/MM/yyyy HH:mm:ss`") $output"
    if($debug) {write-host $msg -foregroundcolor $color}
    $msg | out-file -Filepath $LOG_PATH -append

}

if(-NOT (Test-Path $BACKUP_PATH)) {
    logMsg "Can't not detect $BACKUP_PATH but ignore this if you use net-drive . Trying connect..."
    if($IS_NETDRIVE) {
        $cmd = 'net use $BACKUP_DRIVE \\yourserver\folder'
        Invoke-Expression -Command $cmd
        if(-NOT (Test-Path $BACKUP_PATH)) {
            logMsg "Try $BACKUP_PATH failed." "red"
            exit 1
        }else{
            logMsg "Try connect $BACKUP_PATH success."
        }
    } else {
        logMsg "Not found $BACKUP_PATH" "red"
    }
} else {
    logMsg "Found your backup folder at $BACKUP_PATH" "green"
}

if(-NOT (Test-Path $REVISION_DB)) {
	Get-ChildItem $REPOS_PATH | ?{ $_.PSIsContainer } | select Name, @{l="revision";e={0}} | Export-Csv $REVISION_DB
}

$current_list = Get-ChildItem $REPOS_PATH | ?{ $_.PSIsContainer } | select Name,@{l="revision";e={svnlook.exe youngest $_.FullName}}
$previous_list = Import-Csv $REVISION_DB
#####
$LAST_REV_TABLE=@{}
foreach($r in $previous_list)
{
    $LAST_REV_TABLE[$r.Name]=$r.revision
}
####
$CUR_REV_TABLE=@{}
foreach($r in $current_list)
{
    $CUR_REV_TABLE[$r.Name]=$r.revision
}

####
foreach($repo in $current_list) {
    $name = $repo.Name
    $repo_path = "${REPOS_PATH}\${name}"
    $bk_name = "${name}_${POSTFIX_NAME}"
    $current_revision = $repo.revision
    ## Check if it is new repo from the last backup
    $Is_NewRepo = -NOT $LAST_REV_TABLE.ContainsKey($name)
    if(-NOT $Is_NewRepo){
        $last_revision = $LAST_REV_TABLE[$name]
    }else {
        $last_revision = 0
    }
    
    logMsg "REPO_NAME: $name ; LAST_REV: $last_revision ; CURRENT_REV:$current_revision"  "yellow"
    
    if($Is_NewRepo -OR $current_revision -gt $last_revision) {
        ## Create backup path for repo
        if(-NOT (Test-Path "${BACKUP_PATH}\$name" -pathType container)) {
            New-Item "${BACKUP_PATH}\$name" -type directory
        }
        
        logMsg "REPO_NAME:$name ready to be backuped"
        $cmd = "svnadmin dump $repo_path | ""$7ZIP"" a -si ${BACKUP_PATH}\${name}\${bk_name}.7z"

        logMsg $cmd "Green"

        $start_time = get-date -Format "dd/mm/yyyy HH:mm:ss"
        
        CMD.EXE /C "$cmd"

        $end_time = get-date -Format "dd/mm/yyyy HH:mm:ss"
        
        $Is_Backuped = Test-Path "${BACKUP_PATH}\${name}\${bk_name}.7z"

        if(-NOT $Is_Backuped) {
            logMsg "Backup $name Failed for version $current_revision" "red"
            $exit_status = 1
        }else{
            logMsg "Backup $name success for version $current_revision (run from $start_time to $end_time"
        }
        ### Keep a specified number of files on backup site
        gci "${BACKUP_PATH}\${name}" | where{-NOT $_.PsIsContainer}| sort CreationTime -desc|  select -Skip $KEEPFILES | Tee-object -Variable REMOVED_ITEMS | Remove-Item -Force
        logMsg "Removed $(($REMOVED_ITEMS | Measure-Object –Line).Lines) old items." "red"

    } else {
        logMsg "The current backup is lastest" "Green"
    }

}

##Update databased local
$current_list | Export-Csv $REVISION_DB
##Unmap the net drive
if($IS_NETDRIVE) {CMD.EXE /C "net use $BACKUP_DRIVE /delete"}
exit $exit_status
