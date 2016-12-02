## Unit test:
## $DACL = Get-ServiceDACL <SERVICE_NAME>
## Get-WindowsUserSID
## New-ACEGrant "S-1-5-21-1736027161-2167484431-2811008017-1001" ""
## Add-DACLACE $DACL $ACE
## $newDACL = Add-DACLACE $(Get-ServiceDACL "mysql579") $(New-ACEGrant $(Get-WindowsUserSID) "" )
#foreach( $c in $b ) { $lines += ("{0:X2} - {1}" -f $c, ([char]$c) ) }
#http://stackoverflow.com/questions/4436558/start-stop-a-windows-service-from-a-non-administrator-user-account
#ace_type - "A": ACCESS_ALLOWED_ACE_TYPE,
#ace_flags - n/a,
#rights - CCLCSWRPWPDTLOCRRC,  please refer to the Access Rights and Access Masks and Directory Services Access Rights
#CC: ADS_RIGHT_DS_CREATE_CHILD - Create a child DS object.
#LC: ADS_RIGHT_ACTRL_DS_LIST - Enumerate a DS object.
#SW: ADS_RIGHT_DS_SELF - Access allowed only after validated rights checks supported by the object are performed. This flag can be used alone to perform all validated rights checks of the object or it can be combined with an identifier of a specific validated right to perform only that check.
#RP: ADS_RIGHT_DS_READ_PROP - Read the properties of a DS object.
#WP: ADS_RIGHT_DS_WRITE_PROP - Write properties for a DS object.
#DT: ADS_RIGHT_DS_DELETE_TREE - Delete a tree of DS objects.
#LO: ADS_RIGHT_DS_LIST_OBJECT - List a tree of DS objects.
#CR: ADS_RIGHT_DS_CONTROL_ACCESS - Access allowed only after extended rights checks supported by the object are performed. This flag can be used alone to perform all extended rights checks on the object or it can be combined with an identifier of a specific extended right to perform only that check.
#RC: READ_CONTROL - The right to read the information in the object's security descriptor, not including the information in the system access control list (SACL). (This is a Standard Access Right, please read more http://msdn.microsoft.com/en-us/library/aa379607(VS.85).aspx)
#object_guid - n/a,
#inherit_object_guid - n/a,
## sc sdshow <SERVICE_NAME>
## sc sdset <SERVICE_NAME> "D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;IU)(A;;CCLCSWLOCRRC;;;SU)(A;;RPWPCR;;;S-1-5-21-2103278432-2794320136-1883075150-1000)S:(AU;FA;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;WD)"

## Microsoft Propriatary Code
## Returns $true if the script is running with elevated privilege.
## Returns $false, otherwise.
## [Enum]::GetNames( [System.Management.Automation.CommandTypes] )
### Alias
### All
### Application
### Cmdlet
### Configuration
### ExternalScript
### Filter
### Function
### Script
### Workflow
### function MyFunction2($param1, $param2 ){ $i = 0; while( $i -lt $MyInvocation.MyCommand.Definition.Length ){Write-Host $MyInvocation.MyCommand.Definition.Chars($i) -NoNewline ; $i+=1; } }
function Run-AsAdmin{

	$IsAdmin = Test-IsAdmin 

	if($IsAdmin) {
		$WindowsPrincipal=[System.Security.Principal.WindowsIdentity]::GetCurrent();
		$errorMessage = ("Current user {0} cannot execute as administrator" -f $WindowsPrincipal.Name );
		throw $errorMessage;
	} else {
		$callStack = Get-PSCallStack;
		$calleeFunctionStackEntry = $callStack[0];
		$callerFunctionStackEntry = $callStack[1];
		$callerFunction = ( Get-ChildItem function:\ | Where-Object {$_.Name -eq $callerFunctionStackEntry.Command} );
		$functionArguments = @{}
		foreach( $key in $callerFunction.Parameters.Keys ) {
			$value = ( Get-Variable -ValueOnly -Scope 1 -Name $key );
			$functionArguments.Add($key, $value );
		}
		$completeFunctionNameList = ( Get-ChildItem function:\ );
		$initialFunctionList = ( $Host.Runspace.InitialSessionState.Commands | Where-Object {$_.CommandType -eq "Function"} | Select-Object -Property Name ).Name;
		$customFunctionList = @();
		foreach($function in $completeFunctionNameList) {
			if( -not ($function.Name -in  $initialFunctionList) ) {
				$customFunctionList += $function;
			}
		}
		$functionScript = "";
		foreach($function in $customFunctionList) {
			$functionScript = ("{0}`nfunction {1}" -f $functionScript, $function.Name);
			$functionScript += "{`n"
			if($calleeFunctionStackEntry.Command -ne $function.Name){
			    $functionScript = ("{0}{1}" -f $functionScript, $function.Definition);
			} else {
$functionBody = @"
    `$IsAdmin = Test-IsAdmin
	if( -not ( `$IsAdmin )) {
		`$WindowsPrincipal=[System.Security.Principal.WindowsIdentity]::GetCurrent();
		`$errorMessage = (`"Current user {0} cannot execute as administrator`" -f `$WindowsPrincipal.Name );
		throw `$errorMessage;
	}
"@;
				$functionScript = ("{0}{1}" -f $functionScript, $functionBody);
			}
			$functionScript += "}"
		}
		$functionScript = ("{0}`n{1}" -f $functionScript, $callerFunctionStackEntry.Command);
		foreach($key in $functionArguments.Keys) {
			$functionScript = ("{0} -{1} `"{2}`"" -f $functionScript, $key, $functionArguments[$key]);
		}
		$temporaryDirectory = [System.Io.Path]::GetTempPath();
		$randomGUID = New-Guid;
		$temporaryFileName = ("{0}.PS1" -f  $randomGUID );
		$temporaryFilePath = Join-Path $temporaryDirectory $temporaryFileName;
		try{
		$functionScript | Set-Content $temporaryFilePath
		$arg = ("-NoLogo -NonInteractive -executionpolicy remotesigned -file `"{0}`"" -f $temporaryFilePath);
		Start-Process "powershell.exe"  -Verb Runas -ArgumentList $arg -ErrorAction 'stop'
		} catch [Exception] {
		    $errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		    $errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		    $errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		    $errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		    $errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		    throw $errorMessage;
		} finally {
			if(Test-Path $temporaryFilePath){
			    Remove-Item -Force $temporaryFilePath
			}
		}
	}
}

function Test-IsAdmin {
	try{
    $identity       = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal      = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $administrators = [System.Security.Principal.WindowsBuiltInRole]::Administrator
  
    return $principal.IsInRole($administrators)
	} catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

function Get-WindowsUserSID ( ) {
    $WindowsPrincipal=[System.Security.Principal.WindowsIdentity]::GetCurrent();
	$UserSID = $WindowsPrincipal.User.Value;

	return $UserSID;
}

function Add-DACLACE ( $DACL, $ACE ) {

	$newDACL = "";

	try{
	    $fifthSemiColonX = Get-IndexOfElementX $ACE ";" 5
	    if(($fifthSemiColonX -eq -1) -or ($ACE.Length -lt 3))
	    {
	    	$errorMessage = ("Unsupported ACE format {0}" -f $ACE);
	    	throw $errorMessage;
	    }
	    $userSID = ([String]$ACE).Substring($fifthSemiColonX+1,($ACE.Length-(2+$fifthSemiColonX)));
        $searchToken = (";{0})" -f $userSID);
        if(([String]$DACL).IndexOf($searchToken) -eq -1)
	    {
	    	$newDACL = ( "{0}{1}" -f $DACL, $ACE );
	    }
	    else
	    {
	    	$newDACL = Remove-DACLACE $DACL $ACE
	    	$newDACL = Add-DACLACE $newDACL $ACE
	    }
	    return $newDACL;
	} catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}

}

function Remove-DACLACE ( $DACL, $ACE ) {

	$newDACL = "";
	try {
	    $fifthSemiColonX = Get-IndexOfElementX $ACE ";" 5;
	    if(($fifthSemiColonX -eq -1) -or ($ACE.Length -lt 3))
	    {
	    	$errorMessage = ("Unsupported ACE format {0}" -f $ACE);
	    	throw $errorMessage;
	    }
	    $userSID = ([String]$ACE).Substring($fifthSemiColonX+1,($ACE.Length-(2+$fifthSemiColonX)));
	    $searchToken = (";{0})" -f $userSID);
	    $sidSemiColonX = ([String]$DACL).IndexOf($searchToken);
        if($sidColonX -eq -1)
	    {
		    $newDACL = $DACL; ## ACE not found
	    }
	    else
	    {
		    $parentX = $sidSemiColonX;
		    while(( $DACL[$parentX] -ne '(') -and ($parentX -ge 0)){
                $parentX -= 1;
		    }
		    $newDACL = ([String]$DACL).Remove($parentX,($sidSemiColonX-$ParentX+$searchToken.Length))
	    }
	    return $newDACL;
	} catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

function Set-ServiceDACL ( $ServiceName, $DACLString ) {
	try{
		if(Test-IsAdmin){
			Invoke-expression -Command  "sc.exe sdset `"$ServiceName`" `"$DACLString`""
		} else {
		    Run-AsAdmin
	    }
	}catch [Exception]{
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}function Get-ServiceDACL ( $Servicename ) {
	try{	$sddl = Invoke-expression -Command  "sc.exe sdshow $Servicename" # $Servicename	$parts =  $sddl -split(":")	#$parts.Length	$i = 0	Write-Host "Getting Service DACL for $ServiceName"	While ($i -lt $parts.length) { 		$part = $parts[$i] 		Switch ($part) {			"D" { $i++; Parse-DACL $parts[$i] }		}		$i++	}	return ([String]$sddl).Trim();
	} catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}
function Parse-DACL ( $SDDLIN ) {
	try{    [Array]$sddls = ($SDDLIN).split('(', [System.StringSplitOptions]::RemoveEmptyEntries)    foreach ($SDDLI in $sddls) {		#($SDDLI).replace(')';'') 		#$SDDLI		$tokens = (($SDDLI).replace(')','')).split(";")		If ($tokens[5]) {			If ($tokens[5].length -gt 3) {				[wmi]$obj = 'Win32_SID.SID="{0}"' -f $($tokens[5])				$encoded = [System.Convert]::ToBase64String($obj.BinaryRepresentation)				$obj | Add-Member -MemberType NoteProperty -Name base64_sid -Value $encoded				$userNameString = "$($obj.ReferencedDomainName)\$($obj.AccountName)" ;				if(-not([String]::IsNullOrWhiteSpace($userNameString)) ) {					$userNameString = ( "{0}{1}" -f ([String]$userNameString).Trim(), "`n" )					Write-Host $userNameString -ForegroundColor red -NoNewline				}			}			Else {				$userNameString = "$($Trustees.get_item($tokens[5]))"				if(-not([String]::IsNullOrWhiteSpace($userNameString)) ) {					$userNameString = ( "{0}{1}" -f ([String]$userNameString).Trim(), "`n" )					Write-Host $userNameString -ForegroundColor red  -NoNewline				}			}			$aceTokenTypeDescriptor = $AceType.get_item($tokens[0])			if( -not ( [String]::IsNullOrWhiteSpace($aceTokenTypeDescriptor) ) ) {				$aceTokenTypeDescriptor = ("   {0}`n" -f ([String]$aceTokenTypeDescriptor).Trim() )				Write-Host $aceTokenTypeDescriptor -NoNewline			}			$grants = [regex]::split($tokens[2], '(.{2})');			foreach($grant in $grants ){ 				$grantStringDescriptor = $($PermissionType.get_item($grant))				if( -not ( [String]::IsNullOrWhiteSpace($grantStringDescriptor) ) ) {					$grantStringDescriptor = ("      {0}`n" -f ([String]$grantStringDescriptor).Trim())					Write-Host $grantStringDescriptor -NoNewline				}			}		}	}
	}catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

function New-ACE ($accountSID, $ACETypeName, $PermissionTypeArray ){
	try{
	$newACE = Get-ACETemplate $accountSID;
    $newACE = Set-ACEType $newACE $ACETypeName
	foreach( $PermissionTypeName in $PermissionTypeArray ){
		$newACE = Set-ACEPermissionType $newACE $PermissionTypeName
	}
	return $newACE;
	} catch [Exception] {
				$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

## returns string in ACE format (;;;;;)
## with SID embedded into account
function Get-ACETemplate ( $accountSID ) {

	try{
	$clearedAccountDescriptor = "";	$accountDescriptorFound = $false;	$aceTemplateWithUserAccount = "";	foreach( $key in $Trustees.Keys ) { 		if( $Trustees[$key] -eq $accountSID ) { 			$clearedAccountDescriptor = $Key;			$accountDescriptorFound = $true;		}	}	if($accountDescriptorFound -eq $false) {		$clearedAccountDescriptor = $accountSID;	}	$aceTemplate = "(;;;;;{0})";	$aceTemplateWithUserAccount = ($aceTemplate -f $clearedAccountDescriptor);	return $aceTemplateWithUserAccount;	} catch [Exception] {				$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;	}
}

## if $ACE already has $AceType, replace with proposed
## if $ACE absent, embed
function Set-ACEType( $ACE, $AceTypeName ) {

	try{
	$openingParenthesis_x = -1;
	$firstSemiColon_x = -1;
	$ACETypeCode = "";
	$ACETypeCodeFound = $false;

	$openingParenthesis_x = ([String]$ACE).IndexOF("(");
	$firstSemiColon_x = ([String]$ACE).IndexOF(";");

	if(($openingParenthesis_x -ne 0) -or ($firstSemiColon_x -eq -1))
	{
		$errorMessage = ( "ACE {0} format is not supported" -f $ACE )
		throw $errorMessage;
	}

	## $AceType is missing
	if( $openingParenthesis_x -ne ($firstSemiColon_x-1) )
	{
		$ACE = ([String]$ACE).Remove($openingParenthesis_x,$firstSemiColon_x);
	}

	foreach( $key in $AceType.Keys )
	{
		if($AceType[$key] -eq $AceTypeName)
		{
			$ACETypeCode = $key;
			$ACETypeCodeFound = $true;
		}
	}
	if( $ACETypeCodeFound -eq $false )
	{
		$errorMessage = ( "ACE Type {0} could not be found" -f $AceTypeName );
		throw $errorMessage;
	}

	$ACE = ([String]$ACE).Insert(1,$ACETypeCode);
	
	return $ACE;
	} catch [Exception] {
				$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

## if $ACE already has $AceType, replace with proposed
## if $ACE absent, embed
function Set-ACEPermissionType( $ACE, $AcePermissionTypeName ) {

	try{
	$secondSemiColon_x = -1;
	$thirdSemiColon_x = -1;
	$AcePermissionTypeList = "";
	$AcePermissionTypeCode = "";
	$AcePermissionTypeCodeInList = $false;
	$AcePermissionTypeCodeFound = $false;
	$ACEPermissionTypeCodeX = 0;
	$newACE = $ACE;

	$secondSemiColon_x = Get-IndexOfElementX $ACE ";" 2;
	$thirdSemiColon_x = Get-IndexOfElementX $ACE ";" 3;

	if(($secondSemiColon_x -eq -1) -or ($thirdSemiColon_x -eq -1))
	{
		$errorMessage = ( "ACE {0} format is not supported" -f $ACE )
		throw $errorMessage;
	}

	## $AceType is missing
	if( ( $thirdSemiColon_x - $secondSemiColon_x ) -gt 1 )
	{
		$AcePermissionTypeList = $ACE.Substring( $secondSemiColon_x+1, ($thirdSemiColon_x - ( $secondSemiColon_x + 1)) );
		$newACE = ([String]$ACE).Remove( $secondSemiColon_x + 1, ($thirdSemiColon_x - ( $secondSemiColon_x + 1 )) );
	}

	foreach( $key in $PermissionType.Keys )
	{
		if($PermissionType[$key] -eq $AcePermissionTypeName)
		{
			$AcePermissionTypeCode = $key;
			$AcePermissionTypeCodeFound = $true;
		}
	}
	
	if( $AcePermissionTypeCodeFound -eq $false )
	{
		$errorMessage = ( "ACE Permission Type {0} could not be found" -f $AcePermissionTypeName );
		throw $errorMessage;
	}

	while($ACEPermissionTypeCodeX -lt $AcePermissionTypeList.Length)
	{
		if($AcePermissionTypeCode -eq $AcePermissionTypeList.Substring( $ACEPermissionTypeCodeX, 2 ) )
		{
			$AcePermissionTypeCodeInList = $true;
			break;
		}
		$ACEPermissionTypeCodeX+=2;
	}

	if($AcePermissionTypeCodeInList -eq $false )
	{
		$AcePermissionTypeList = ("{0}{1}" -f $AcePermissionTypeList, $AcePermissionTypeCode);
		$newACE = $newACE.Insert( $secondSemiColon_x+1,$AcePermissionTypeList);
	}

	return $newACE;
	} catch [Exception] {
		$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

## Find certain string within another string x number of time s
## and report back position ( zero based ) of the match found time #x
function Get-IndexOfElementX( $stringToSearch, $element, $elementx ) {

	try{
	$x = 0;
	$elementPos = 0;

    while( $true )
	{
		$elementPos = ([String]$stringToSearch).IndexOf($element,$elementPos);
		$x += 1;
		if( ( $elementPos -eq -1 ) -or ( $x -ge $elementx ) )
		{
			break;
		}
		$elementPos+=1;
	}
	return $elementPos;
	} catch [Exception] {
				$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

function New-ACEGrant ( $accountSID, $privilegeLevel ){

	try{
	$ACETypeName = "ACCESS ALLOWED";
	$PermissionTypeArray = @();

	if( $privilegeLevel.StartsWith("admin", [System.StringComparison]::InvariantCultureIgnoreCase) )
	{
		$PermissionTypeArray = @(
		"Query Conf",
		"Change Conf",
		"QueryStat",
		"EnumDeps",
        "Start",
        "Stop",
        "Pause",
		"Interrogate",
		"Standard Delete",
		"Read Control",
		"Write DAC",
		"Write Owner"
	    );
	}
	else
	{
		$PermissionTypeArray = @(
		"QueryStat",
		"EnumDeps",
        "Start",
        "Stop",
        "Pause"
	    );
	}

	$newACE = New-ACE $accountSID $ACETypeName $PermissionTypeArray;

	return $newACE;
	} catch [Exception] {
				$errorMessage = ( "Error in {0}`n" -f $MyInvocation.MyCommand );
		$errorMessage = ( "{0}Error line: {1}`n" -f $errorMessage, $_.InvocationInfo.Line );
		$errorMessage = ( "{0}Error line: {1}, symbol: {1} `n" -f $errorMessage, $_.InvocationInfo.ScriptLineNumber, $_.InvocationInfo.OffsetInLine );
		$errorMessage = ( "{0}Time: {1}`n" -f $errorMessage, [DateTime]::UTCNow.ToString("yyyy-MM-dd HH-mm-ss.fff") );
		$errorMessage = ( "{0}Error message: {1}" -f $errorMessage, $_.Exception.Message );
		throw $errorMessage;
	}
}

$AceType = @{"A" = "ACCESS ALLOWED";
"D" = "ACCESS DENIED";"OA" = "OBJECT ACCESS ALLOWED: ONLY APPLIES TO A SUBSET OF THE OBJECT(S).";"OD" = "OBJECT ACCESS DENIED: ONLY APPLIES TO A SUBSET OF THE OBJECT(S).";"AU" = "SYSTEM AUDIT";"AL" = "SYSTEM ALARM";"OU" = "OBJECT SYSTEM AUDIT";"OL" = "OBJECT SYSTEM ALARM";"ML" = "MANDATORY LABEL"}
 
$AceFlags = @{"CI" = "CONTAINER INHERIT: Child objects that are containers, such as directories, inherit the ACE as an explicit ACE.";"OI" = "OBJECT INHERIT: Child objects that are not containers inherit the ACE as an explicit ACE.";"NP" = "NO PROPAGATE: ONLY IMMEDIATE CHILDREN INHERIT THIS ACE.";"IO" = "INHERITANCE ONLY: ACE DOESN'T APPLY TO THIS OBJECT; BUT MAY AFFECT CHILDREN VIA INHERITANCE.";"ID" = "ACE IS INHERITED";"SA" = "SUCCESSFUL ACCESS AUDIT";"FA" = "FAILED ACCESS AUDIT"
}
 
$PermissionType = @{
"CC" = "Query Conf";"DC" = "Change Conf";"LC" = "QueryStat";"SW" =  "EnumDeps";"RP" =  "Start";"WP" =  "Stop";"DT" =  "Pause";"LO" =  "Interrogate";"CR" =  "UserDefined";"GA" =  "Generic All";"GX" =  "Generic Execute";"GW" =  "Generic Write";"GR" =  "Generic Read";"SD" =  "Standard Delete";"RC" =  "Read Control";"WD" =  "Write DAC";"WO" =  "Write Owner"
}

$Trustees = @{
"AO" = "Account operators";"RU" = "Alias to allow previous Windows 2000";"AN" = "Anonymous logon";"AU" = "Authenticated users";"BA" = "Built-in administrators";"BG" = "Built-in guests";"BO" = "Backup operators";"BU" = "Built-in users";"CA" = "Certificate server administrators";"CG" = "Creator group";"CO" = "Creator owner";"DA" = "Domain administrators";"DC" = "Domain computers";"DD" = "Domain controllers";"DG" = "Domain guests";"DU" = "Domain users";"EA" = "Enterprise administrators";"ED" = "Enterprise domain controllers";"WD" = "Everyone";"PA" = "Group Policy administrators";"IU" = "Interactively logged-on user";"LA" = "Local administrator";"LG" = "Local guest";"LS" = "Local service account";"SY" = "Local system";"NU" = "Network logon user";"NO" = "Network configuration operators";"NS" = "Network service account";"PO" = "Printer operators";"PS" = "Personal self";"PU" = "Power users";"RS" = "RAS servers group";"RD" = "Terminal server users";"RE" = "Replicator";"RC" = "Restricted code";"SA" = "Schema administrators";"SO" = "Server operators";"SU" = "Service logon user"}