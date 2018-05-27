<#  
.SYNOPSIS  
    Extract T-SQL code from multiple DTSX files (handles both SQL 2012 and older versions

.NOTES  
    Author     : Arvind Shyamsundar (arvindsh@microsoft.com)
	
.PARAMETERS
	-RootFolder: full path to the root folder which contains the RDL files
	-Recurse: whether to search sub folders or not

.LINK  
    http://blogs.msdn.com/b/arvindsh
	
.HISTORY
	2013.05.14	First version for blog
#>

param
(
	[string] 	$RootFolder,
	[bool]	$Recurse
)

if ($RootFolder -eq "")
{
	Write-Error "Please specify a valid root folder path (-RootFolder)"
	Exit
}

#	Write-Host "Looking for packages at folder " $RootFolder

if ($Recurse -eq $true)
{
	$dtsxfiles = get-childitem -path $RootFolder -Filter "*.dtsx" -Recurse
}
else
{
	$dtsxfiles = get-childitem -path $RootFolder -Filter "*.dtsx"
}

foreach ($filename in $dtsxfiles)
{
	[xml]$xml =get-content $filename.FullName
	$ns = new-object Xml.XmlNamespaceManager ($xml.NameTable)
	$ns.AddNamespace("SQLTask", "www.microsoft.com/sqlserver/dts/tasks/sqltask")
	$ns.AddNamespace("DTS", "www.microsoft.com/SqlServer/Dts")

	[int]$pkgformatver = [int]::Parse($xml.SelectSingleNode("//DTS:Property[@DTS:Name='PackageFormatVersion']", $ns).InnerText)

	if ($pkgformatver -le 3)
	{
		# this is the SQL 2008 and below format
		$xml.SelectNodes("//SQLTask:SqlTaskData[@SQLTask:SqlStmtSourceType = 'DirectInput' and @SQLTask:IsStoredProc='False']", $ns) | foreach-object {	
			$taskname = $_.SelectSingleNode("../../DTS:Property[@DTS:Name='ObjectName']", $ns).InnerText
			$_.Attributes | foreach-object {
				if ($_.Name -eq "SQLTask:SqlStatementSource")
				{
					if ($_.Value.Trim() -ne "")
					{
						("-- ~~" + $filename.FullName + "; task " + $taskname + "~~")
						$_.Value.ToString()
						"GO"
					}
				}
			}	
		}
	}
	else
	{
		# the new SQL 2012 format; default property values are not mentioned therein hence we need to do a count check.
		$xml.SelectNodes("//SQLTask:SqlTaskData[(count(./@SQLTask:SqlStmtSourceType) = 0 or @SQLTask:SqlStmtSourceType = 'DirectInput') and (count(./@SQLTask:IsStoredProc) = 0 or @SQLTask:IsStoredProc='False')]", $ns) | foreach-object {	
			$taskname = $_.SelectSingleNode("../../@DTS:ObjectName", $ns).Value
			$_.Attributes | foreach-object {
				if ($_.Name -eq "SQLTask:SqlStatementSource")
				{
					if ($_.Value.Trim() -ne "")
					{
						("-- ~~" + $filename.FullName + "; task " + $taskname + "~~")
						$_.Value.ToString()
						"GO"
					}
				}
			}	
		}
	}
}