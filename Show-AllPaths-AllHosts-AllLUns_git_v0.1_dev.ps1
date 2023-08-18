#Requires -RunAsAdministrator
#Requires -Version 5.1

<#
.Synopsis
   Validate All Paths of All Luns of All Host of a Given vCenter
.DESCRIPTION
   Validate All Paths of All Luns of All Host of a Given vCenter
.EXAMPLE
   Just Run the Script
.EXAMPLE
   Another example of how to use this cmdlet
.SOURCE
   Based on KB https://kb.vmware.com/s/article/1003973
   Based on Article: https://docs.netapp.com/us-en/ontap-fli/san-migration/task_multipath_verification_for_esxi_hosts.html
.CREATOR
   Juliano Alves de Brito Ribeiro (find me at julianoalvesbr@live.com or https://github.com/julianoabr or https://youtube.com/@powershellchannel)
.VERSION
   0.2
.ENVIRONMENT
   Production
.TO THINK

PSALMS 19. v 1 - 4
1. The heavens declare the glory of God;
the skies proclaim the work of his hands.
2. Day after day they pour forth speech;
night after night they reveal knowledge.
3. They have no speech, they use no words;
no sound is heard from them.
4. Yet their voice goes out into all the earth,
their words to the ends of the world.

#>


Set-executionpolicy -Scope CurrentUser -ExecutionPolicy Unrestricted -Verbose -Force -ErrorAction SilentlyContinue # Execute Policy  

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

$outputPath = "$env:SystemDrive\Output\Vsphere\ESXiHost\Paths"

#VALIDATE IF OPTION IS NUMERIC
function isNumeric ($x) {
    $x2 = 0
    $isNum = [System.Int32]::TryParse($x, [ref]$x2)
    return $isNum
} #end function is Numeric


#FUNCTION CONNECT TO VCENTER
function Connect-ToVcenterServer
{
    [CmdletBinding()]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [ValidateSet('Manual','Automatic')]
        $methodToConnect = 'Manual',

        # Param2 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [ValidateSet('vc1','vc2','vc3','vc4','vc5','vc6','vc7')]
        [System.String]$vCenterToConnect, 
        
        [Parameter(Mandatory=$false,
                   Position=2)]
        [System.String[]]$VCServers, 
                
        [Parameter(Mandatory=$false,
                   Position=3)]
        [ValidateSet('domain.local','vsphere.local','system.domain','mydomain.automite')]
        [System.String]$suffix, 

        [Parameter(Mandatory=$false,
                   Position=4)]
        [ValidateSet('80','443')]
        [System.String]$port = '443'
    )

        

    if ($methodToConnect -eq 'Automatic'){
                
        $Script:workingServer = $vCenterToConnect + '.' + $suffix
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $Port -WarningAction Continue -ErrorAction Stop
           
    
    }#end of If Method to Connect
    else{
        
        Disconnect-VIServer -Server * -Confirm:$false -Force -Verbose -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

        $workingLocationNum = ""
        
        $tmpWorkingLocationNum = ""
        
        $Script:WorkingServer = ""
        
        $i = 0

        #MENU SELECT VCENTER
        foreach ($vcServer in $vcServers){
	   
                $vcServerValue = $vcServer
	    
                Write-Output "            [$i].- $vcServerValue ";	
	            $i++	
                }#end foreach	
                Write-Output "            [$i].- Exit this script ";

                while(!(isNumeric($tmpWorkingLocationNum)) ){
	                $tmpWorkingLocationNum = Read-Host "Type Vcenter Number that you want to connect"
                }#end of while

                    $workingLocationNum = ($tmpWorkingLocationNum / 1)

                if(($WorkingLocationNum -ge 0) -and ($WorkingLocationNum -le ($i-1))  ){
	                $Script:WorkingServer = $vcServers[$WorkingLocationNum]
                }
                else{
            
                    Write-Host "Exit selected, or Invalid choice number. End of Script " -ForegroundColor Red -BackgroundColor White
            
                    Exit;
                }#end of else

        #Connect to Vcenter
        $Script:vcInfo = Connect-VIServer -Server $Script:WorkingServer -Port $port -WarningAction Continue -ErrorAction Continue
  
    
    }#end of Else Method to Connect

}#End of Function Connect to Vcenter

#DEFINE VCENTER LIST
$vcServerList = @();

#ADD OR REMOVE vCenters - Insert FQDN of your vCenter(s)        
$vcServerList = ('vc1','vc2','vc3','vc4','vc5','vc6','vc7') | Sort-Object


Do
{
 
        $tmpMethodToConnect = Read-Host -Prompt "Type (Manual) if you want to choose VC to Connect. Type (Automatic) if you want to Type the Name of VC to Connect"

        if ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)"){
    
            Write-Host "You typed an invalid word. Type only (manual) or (automatic)" -ForegroundColor White -BackgroundColor Red
    
        }
        else{
    
            Write-Host "You typed a valid word. I will continue =D" -ForegroundColor White -BackgroundColor DarkBlue
    
        }
    
    }While ($tmpMethodToConnect -notmatch "^(?:manual\b|automatic\b)")


if ($tmpMethodToConnect -match "^\bautomatic\b$"){

    $tmpSuffix = Read-Host "Write the suffix of VC that you want to connect (host.intranet or uolcloud.intranet)"

    $tmpVC = Read-Host "Write the hostname of VC that you want to connect"

    Connect-ToVcenterServer -vCenterToConnect $tmpVC -suffix $tmpSuffix -methodToConnect Automatic

}
else{

    Connect-ToVcenterServer -methodToConnect $tmpMethodToConnect -VCServers $vcServerList

}

#MAIN SCRIPT

$actualDate = (Get-date -Format "ddMMyyyy-HHmm").ToString()

$ESXiHostList = @()

$dsNameList = @()

#HOSTS
$ESXiHostList = (Get-VMHost | Select-Object -ExpandProperty Name | Sort-Object)

#Datastores
$dsNameList = (Get-Datastore | Where-Object -FilterScript {$PSItem.ExtensionData.Info.Vmfs.Local -eq $false} | Select-Object -ExpandProperty Name | Sort-Object)


foreach ($ESXiHost in $ESXiHostList){
    
        
    foreach ($dsName in $dsNameList)
    {
        
        $dsObj = Get-Datastore -Name $dsName

        $dsNAADevice = $dsObj.ExtensionData.Info.Vmfs.Extent.DiskName

        $esxcli = Get-EsxCli -VMHost $ESXiHost

        $esxcli.storage.core.path.list() | Where-Object {$_.Device -match $dsNAADevice} | Select-Object -Property @{n='ESXi_Name';e={$ESXiHost}},Device,@{n='DS_Name';e={$dsName}},AdapterIdentifier,RunTimeName,State |
Export-Csv -Path "$outputPath\AllPaths-AllHosts-$Script:WorkingServer-$actualDate.csv" -NoTypeInformation -Append


    }#end of foreach DS

 

}#end forEach Esxi Host
