param (
 [string]$Message
)
try
{
 $ErrorActionPreference = 'Stop';
 $Error.Clear();

 $verbose = $env:VERBOSE
 $Identifier = $env:BLUESKY_IDENTIFIER
 $ApiKey = $env:BLUESKY_API_KEY

 $baseUri = 'https://bsky.social'
 $protocol = 'xrpc'
 $createSession = 'com.atproto.server.createSession'
 $createRecord = 'com.atproto.repo.createRecord'

 $CreateSessionUri = "$($baseUri)/$($protocol)/$($createSession)"
 $CreateRecordUri = "$($baseUri)/$($protocol)/$($createRecord)"

 if ($verbose.ToLower() -eq 'verbose')
 {
  Write-Host "Post2BlueSkey DEBUG"
  Write-Host "CreateSessionUri : $($CreateSessionUri)"
  Write-Host "CreateRecordUri  : $($CreateRecordUri)"
  Write-Host "Message          : $($Message)"
 }

 $AuthBody = @{'identifier' = $Identifier; 'password' = $ApiKey }
 $Headers = @{}
 $Headers.Add('Content-Type', 'application/json')

 $Response = Invoke-RestMethod -Uri $CreateSessionUri -Method Post -Body ($AuthBody | ConvertTo-Json -Compress) -Headers $Headers
 $Headers.Add('Authorization', "Bearer $($Response.accessJwt)")

 $createdAt = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.ffffffZ"
 $MarkdownLinkPattern = '\[([^\]]+)\]\((http[s]?://[^\s,)]+)\)'

 $Links = @()

 do
 {
  $result = $Message -match $MarkdownLinkPattern
  if ($result)
  {
   $anchor = $Matches[1]
   $url = $Matches[2]
   $Message = $Message.Replace($Matches[0], $anchor)

   $startIndex = $Message.IndexOf($anchor)
   $endIndex = $startIndex + $anchor.Length
   $Links += New-Object -TypeName psobject -Property @{
    Name         = $anchor
    Url          = $url
    "StartIndex" = $startIndex
    "EndIndex"   = $endIndex
   }
  }
 } until ($result -eq $false)

 if ($links)
 {
  $Facets = @()
  foreach ($Link in $Links)
  {
   $features = @()
   $features += New-Object -TypeName psobject -Property @{
    '$type' = "app.bsky.richtext.facet#link"
    'uri'   = $Link.Url
   }
   $index = New-Object -TypeName psobject -Property @{
    "byteStart" = $Link.startIndex
    "byteEnd"   = $Link.endIndex
   }
   $Facets += New-Object -TypeName psobject -Property @{
    'index'    = $index
    'features' = $features
   }
  }
  $Record = New-Object -TypeName psobject -Property @{
   '$type'     = "app.bsky.feed.post"
   'text'      = $Message
   "createdAt" = $createdAt
   'facets'    = $Facets
  }
 }
 else
 {
  $Record = New-Object -TypeName psobject -Property @{
   '$type'     = "app.bsky.feed.post"
   'text'      = $Message
   "createdAt" = $createdAt
  }
 }

 $Post = New-Object -TypeName psobject -Property @{
  'repo'       = $Identifier
  'collection' = 'app.bsky.feed.post'
  record       = $Record
 }

 if ($verbose.ToLower() -eq 'verbose')
 {
  $Post | ConvertTo-Json -Depth 5
 }

 Invoke-RestMethod -Uri $CreateRecordUri -Method Post -Body ($Post | ConvertTo-Json -Depth 10 -Compress) -Headers $Headers
}
catch
{
 $_.InvocationInfo | Out-String;
 throw $_.Exception.Message;
}