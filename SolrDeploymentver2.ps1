<#
	Solr deployment script
	Features to develop
	1. Local deployment - with and without SSL
	2. Solr Cloud
	3. Minimize parameters
	4. Options to remove solr
	5. Solr as service
	6. Make ps1 as bat or exe
	7. Create log
#>

#===================Detail (Value here can be configure)======================================#
$FolderName			= "SolrDeployDir"
$InstanceName		= 'sc940xp0rev3604'
$SolrVersion		= 'solr-8.4.0'
$SolrCloud			= $false
$EnableSolrSSL		= $true
$storepass			= 'secret' #min 6 character
#add solr cloud capability


#======================Value not to be configure=====================#
$SolrPort1				= '8983'
$SolrPort2				= '7574'
$JREBinDir				= "$Env:Java_Home"+"\bin"
$SolrUrl				= 'https://archive.apache.org/dist/lucene/solr/'+$SolrVersion.Substring(5)+'/'+$SolrVersion+'.zip'
$FolderDir				= 'C:\'+$FolderName
$SolrDir				= $FolderDir + '\' + $SolrVersion
$zipfile				= $FolderDir + '\' +$SolrVersion+'.zip'
$solrIndexesDir			= $FolderDir+'\'+$SolrVersion+'\server\solr\'
$_defaultdir			= $FolderDir+'\'+$SolrVersion+'\server\solr\configsets\_default\'
$manageschemalocation	= $solrIndexesDir+'\configsets\_default\conf\managed-schema'
$manageSchemabackup		= $solrIndexesDir+'\configsets\_default\conf\managed-schemabackup'
$errorAction			= 'stop'
$keystorep12			= $InstanceName+'.keystore.p12';
$keystorejks			= $InstanceName+'.keystore.jks';
$SolrBinDir				= $SolrDir + '\bin';
$solrEtcDir				= $SolrDir + '\server\etc\'
$SolrInCmdDir			= $SolrBinDir + '\solr.in.cmd'
$SolrInCmdBackupDir		= $SolrBinDir + '\solr.in.cmd.backup'
$HTTP_Protocol			= 'http'
if($EnableSolrSSL){$HTTP_Protocol='https'} else {$HTTP_Protocol='http'}


#=================Sitecore Indexes Name===============================#
$coreindex            = $InstanceName+'_core_index'
$masterindex          = $InstanceName+'_master_index'
$webindex             = $InstanceName+'_web_index'
$madefmasterindex     = $InstanceName+'_marketingdefinitions_master'
$madefwebindex        = $InstanceName+'_marketingdefinitions_web'
$maassetmasterindex   = $InstanceName+'_marketing_asset_index_master'
$maassetwebindex      = $InstanceName+'_marketing_asset_index_web'
$testingindex         = $InstanceName+'_testing_index'
$suggesttestindex     = $InstanceName+'_suggested_test_index'
$fxmmasterindex       = $InstanceName+'_fxm_master_index'
$fxmwebindex          = $InstanceName+'_fxm_web_index'
$personalizationindex = $InstanceName+'_personalization_index'


# ======================Download Solr from apache=====================#
function New-SolrDownload {
	Write-Output "Testing $FolderDir existance."
	if(Test-Path -path $FolderDir){
		Write-Output "$FolderDir is exist. Please specify other value for `$FolderName" -ErrorAction $errorAction
	}
	else{
		New-Item -Path $FolderDir -ItemType Directory
		Write-Output "$FolderDir created"
	}

	if(Test-Path -path $zipfile){
		Remove-Item -Path $zipfile -Force -Recurse
		Write-Output "$zipfile is removed."
	}

	Write-Output "Downloading $SolrVersion at $SolrUrl"
	Import-Module BitsTransfer
	Start-BitsTransfer -Source $SolrUrl -Destination $FolderDir
	Write-Output "$SolrVersion is downloaded at $SolrDir"

	# unzip file
	if(Test-Path -path $SolrDir){
		Remove-Item -Path $SolrDir -Force -Recurse 
	}
	
	Expand-Archive -LiteralPath $zipfile -DestinationPath $FolderDir -Force
}


# ====================create backup for managed-schema==================#
function Update-ManagedSchema {
	if(Test-Path -path $manageSchemabackup){
		Write-Output '$manageSchemabackup is exist. Removing current $manageschemalocation...'
		Remove-Item -path $manageschemalocation
		Write-Output '$manageSchemabackup is removed.'
	}

	Write-Output 'Creating $manageSchemabackup...'
	Copy-Item $manageschemalocation -Destination $manageSchemabackup -Recurse -Force
	Write-Output '$manageSchemabackup is re-created'

	# =====================Update managed-schema==================================#
	#$getcontent = Get-Content -Path $manageschemalocation -Raw
	# Add unique_id field
	((Get-Content -Path $manageschemalocation -Raw) -replace "<uniqueKey>id</uniqueKey>", "<uniqueKey>_uniqueid</uniqueKey>") |Set-Content $manageschemalocation

	# Add unique_id field
	((Get-Content -Path $manageschemalocation -Raw) -replace '<field name="id" type="string" indexed="true" stored="true" required="true" multiValued="false" />', "<field name=""_uniqueid"" type=""string"" indexed=""true"" required=""true"" stored=""true""/>`n`t<field name=""id"" type=""string"" indexed=""true"" stored=""true"" required=""true"" multiValued=""false"" />") | Set-Content $manageschemalocation

}


# =================Create Solr Core==========================================#
function Set-StandaloneSolrCores {
	$Indexes = @($coreindex, $masterindex, $webindex, $madefmasterindex, $madefwebindex, $maassetmasterindex, $maassetwebindex, $testingindex, $suggesttestindex, $fxmmasterindex, $fxmwebindex, $personalizationindex )

	foreach ($index in $Indexes){

		if(Test-Path -path $solrIndexesDir$index)
		{
			Remove-Item -path $solrIndexesDir$index -Recurse -Force
			Write-Output '$solrIndexesDir$index is removed.'
		}
		Write-Output 'Creating $solrIndexesDir$index...'
		New-Item -Path $solrIndexesDir$index -ItemType Directory
		Get-ChildItem -Path $_defaultdir | ForEach-Object {Copy-Item $_.FullName -Destination $solrIndexesDir$index -Recurse -Force}
		New-Item -Path $solrIndexesDir$index\core.properties -ItemType File
		Add-Content -Path $solrIndexesDir$index\core.properties -value "name=$index`nconfig=solrconfig.xml`nupdate.autoCreateFields=false`ndataDir=data"
		Write-Output '$solrIndexesDir$index is created.'
	}
}

function Set-SolrCloudSetup{
	#create sitecore_indexes folder here

}


# ================================Setup Solr ==============================#
function Set-SolrCertificates {
	# ===========Create KeyStore===================#
	Set-Location $JREBinDir;

	if(Test-Path -path $JREBinDir$keystorejks){
		Write-Output "$JREBinDir$keystorejks is exist"
		Remove-Item -path $JREBinDir$keystorejks 
		Write-Output "$JREBinDir$keystorejks is deleted from $JREBinDir"
	}

	keytool.exe -genkeypair -alias $InstanceName -keyalg RSA -keysize 2048 -keypass secret -storepass secret -validity 9999 -keystore $keystorejks -ext SAN=DNS:localhost,IP:127.0.0.1 -dname "CN=$InstanceName, OU=Organizational Unit, O=Organization, L=Location, ST=State, C=Country"
	Write-Output "$JREBinDir$keystorejks is created in $JREBinDir"
	
	# ===========Generate Certificate===================#
	if(Test-Path -path $JREBinDir$keystorep12){
		Write-Output "$JREBinDir$keystorep12 is exist"
		Remove-Item -path $JREBinDir$keystorep12
		Write-Output "$JREBinDir$keystorep12 is deleted from $JREBinDir"
	}

	keytool.exe -importkeystore -srckeystore $keystorejks -destkeystore $keystorep12 -srcstoretype jks -deststoretype pkcs12

	# Manually enter 'Enter destination keystore password:' ($storepass)
	# Manually enter 'Re-enter new password:'($storepass)
	# Manually enter 'Enter source keystore password'($storepass)
	Write-Output "$JREBinDir$keystorep12 is created in $JREBinDir"

	# ===========Install Certificate===================#
	$certpath=Get-ChildItem -Path Cert:\LocalMachine\Root | Where-Object {$_.FriendlyName -eq $InstanceName}
	if($certpath){
		$certpath|Remove-Item
		Write-Output "$certpath is deleted from Cert:\LocalMachine\Root"
	}

	Import-PfxCertificate -FilePath $JREBinDir$keystorep12 -CertStoreLocation Cert:\LocalMachine\Root\ -Password (ConvertTo-SecureString -String $storepass -AsPlainText -Force)
	Write-Output "Certificate with Friendly Name $InstanceName is created in Cert:\LocalMachine\Root\"
	# move the certificate to Solr Directory
	Copy-Item -Path $JREBinDir$keystorejks -Destination $solrEtcDir
	Write-Output "$JREBinDir$keystorejks is created in $solrEtcDir"
	Remove-Item -path $JREBinDir$keystorejks
	Write-Output "$JREBinDir$keystorejks is removed from $JREBinDir"
	
	Copy-Item -Path $JREBinDir$keystorep12 -Destination $solrEtcDir
	Write-Output "$JREBinDir$keystorep12 is created in $solrEtcDir"
	Remove-Item -path $JREBinDir$keystorep12
	Write-Output "$JREBinDir$keystorep12 is removed from $JREBinDir"
	
	# ===========Enable SSL in Solr===================#
	# backup solr.in.cmd file
	if(Test-Path -path $SolrInCmdBackupDir){
		Write-Output "$SolrBinDir\solr.in.cmd.backup is exist. New copy of solr.in.cmd.backup is not created."
	}
	else{
		Copy-Item $SolrInCmdDir -Destination $SolrInCmdBackupDir -Force
		Write-Output "solr.in.cmd.backup is created in $SolrBinDir"
	}

	# uncomment solr_ssl related configuration
	#$getSolrSSLContent = Get-Content -Path $SolrInCmdDir -Raw
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_ENABLED=true", "set SOLR_SSL_ENABLED=true") | Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_KEY_STORE=etc/solr-ssl.keystore.jks", "set SOLR_SSL_KEY_STORE=etc/$InstanceName.keystore.jks") | Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_KEY_STORE_PASSWORD=secret", "set SOLR_SSL_KEY_STORE_PASSWORD=$storepass") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_TRUST_STORE=etc/solr-ssl.keystore.jks", "set SOLR_SSL_TRUST_STORE=etc/$InstanceName.keystore.jks") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_TRUST_STORE_PASSWORD=secret", "set SOLR_SSL_TRUST_STORE_PASSWORD=$storepass") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_NEED_CLIENT_AUTH=false", "set SOLR_SSL_NEED_CLIENT_AUTH=false") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_WANT_CLIENT_AUTH=false", "set SOLR_SSL_WANT_CLIENT_AUTH=false") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_CLIENT_HOSTNAME_VERIFICATION=false", "set SOLR_SSL_CLIENT_HOSTNAME_VERIFICATION=false") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_CHECK_PEER_NAME=true", "set SOLR_SSL_CHECK_PEER_NAME=true") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_KEY_STORE_TYPE=JKS", "set SOLR_SSL_KEY_STORE_TYPE=JKS") |Set-Content $SolrInCmdDir
	((Get-Content -Path $SolrInCmdDir -Raw) -replace "REM set SOLR_SSL_TRUST_STORE_TYPE=JKS", "set SOLR_SSL_TRUST_STORE_TYPE=JKS") |Set-Content $SolrInCmdDir

}

#================== Running Solr =================#
function Set-RunningSolr {
	#============Start Solr with SSL============#
	Set-Location $SolrDir;
	bin\Solr.cmd stop -all;
	if ($SolrCloud){
		#SolrCloud example with internal zookeeper and example GettingStarted collection
		bin\Solr.cmd start -e cloud -noprompt;
		Write-Output "Starting Solr at port $SolrPort1"
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		(Invoke-WebRequest '$HTTP_Protocol://localhost:$SolrPort1/solr/#/').statuscode
		If ($HTTP_Status -eq 200)
		{
			Write-Host "$HTTP_Response.StatusCode Site is OK!"
			Write-Host "Launch Solr in browser(google)"
			[System.Diagnostics.Process]::Start('$HTTP_Protocol://localhost:$SolrPort1/solr/#/')
		}
	}
	else{
		bin\Solr.cmd start -p $SolrPort1;
		Write-Output "Starting Solr at port $SolrPort1"
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		(Invoke-WebRequest '$HTTP_Protocol://localhost:$SolrPort1/solr/#/').statuscode
		If ($HTTP_Status -eq 200)
		{
			Write-Host "$HTTP_Response.StatusCode Site is OK!"
			Write-Host "Launch Solr in browser(google)"
			[System.Diagnostics.Process]::Start('$HTTP_Protocol://localhost:$SolrPort1/solr/#/')
		}
	}
	Write-Output '------End------'
}

#===================== Main area =====================#
# Here is where functions are called
New-SolrDownload
Update-ManagedSchema
if($EnableSolrSSL) {Set-SolrCertificates}
if($SolrCloud) {Set-SolrCloudSetup} else {Set-StandaloneSolrCores}
Set-RunningSolr
#populate
#rebuild index




