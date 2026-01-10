param(
  [int]$Port = 8000,
  [string]$RootPath,
  [switch]$SpaFallback
)

function Get-MimeType {
  param([string]$Path)
  $ext = [IO.Path]::GetExtension($Path).ToLowerInvariant()
  switch ($ext) {
    ".html" { "text/html" }
    ".htm"  { "text/html" }
    ".css"  { "text/css" }
    ".js"   { "application/javascript" }
    ".json" { "application/json" }
    ".mp3"  { "audio/mpeg" }
    ".ogg"  { "audio/ogg" }
    ".wav"  { "audio/wav" }
    ".m4a"  { "audio/mp4" }
    ".png"  { "image/png" }
    ".jpg"  { "image/jpeg" }
    ".jpeg" { "image/jpeg" }
    ".svg"  { "image/svg+xml" }
    ".gif"  { "image/gif" }
    ".webp" { "image/webp" }
    ".ico"  { "image/x-icon" }
    ".woff" { "font/woff" }
    ".woff2"{ "font/woff2" }
    default { "application/octet-stream" }
  }
}

function Resolve-FilePath {
  param([string]$Root, [string]$Relative, [switch]$Spa)
  $rel = [Uri]::UnescapeDataString($Relative.TrimStart('/'))
  if ([string]::IsNullOrWhiteSpace($rel)) { $rel = 'index.html' }
  $path = Join-Path $Root $rel
  if (Test-Path $path -PathType Container) { $path = Join-Path $path 'index.html' }
  if (-not (Test-Path $path -PathType Leaf) -and $Spa.IsPresent) { $path = Join-Path $Root 'index.html' }
  return $path
}

if (-not $RootPath -or -not (Test-Path $RootPath -PathType Container)) {
  $repoRoot = (Split-Path -Parent $PSScriptRoot)
  $candidates = @(
    (Join-Path $repoRoot 'visual-novel\out'),
    (Join-Path $repoRoot 'visual-novel-out'),
    (Join-Path $repoRoot 'out'),
    (Join-Path $repoRoot 'visual-novel')
  )
  foreach ($c in $candidates) {
    if (Test-Path $c -PathType Container) { $RootPath = $c; break }
  }
}

if (-not $RootPath -or -not (Test-Path $RootPath -PathType Container)) {
  Write-Error "RootPath가 존재하지 않습니다. -RootPath 로 빌드 출력 폴더(out)를 지정하세요."
  exit 1
}

Write-Host "RootPath: $RootPath"
Add-Type -AssemblyName System.Net

# Try HttpListener first
$http = $null
$prefix = "http://localhost:$Port/"
try {
  $http = [System.Net.HttpListener]::new()
  $http.Prefixes.Add($prefix)
  $http.Start()
  Write-Host "Serving $RootPath at $prefix (HttpListener)"
} catch {
  Write-Warning "HttpListener failed: $($_.Exception.Message). Falling back to TcpListener."
}

if ($http) {
  try {
    while ($http.IsListening) {
      $ctx = $http.GetContext()
      $req = $ctx.Request
      $res = $ctx.Response
      $path = Resolve-FilePath -Root $RootPath -Relative $req.Url.AbsolutePath -Spa:$SpaFallback
      if (Test-Path $path -PathType Leaf) {
        $bytes = [IO.File]::ReadAllBytes($path)
        $res.ContentType = Get-MimeType -Path $path
        $res.ContentLength64 = $bytes.Length
        $res.StatusCode = 200
        $res.OutputStream.Write($bytes,0,$bytes.Length)
      } else {
        $res.StatusCode = 404
      }
      $res.OutputStream.Close()
    }
  } finally { $http.Stop() }
  return
}

# TcpListener fallback (no URL ACL required)
try {
  $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
  $tcp.Start()
  Write-Host "Serving $RootPath at http://localhost:$Port (TcpListener)"
} catch {
  Write-Error "Failed to start TcpListener on port ${Port}: $($_.Exception.Message)"
  exit 1
}

while ($true) {
  $client = $tcp.AcceptTcpClient()
  try {
    $stream = $client.GetStream()
    $reader = New-Object IO.StreamReader($stream)
    $writer = New-Object IO.StreamWriter($stream)
    $writer.AutoFlush = $true

    $requestLine = $reader.ReadLine()
    if (-not $requestLine) { $client.Close(); continue }
    $parts = $requestLine.Split(' ')
    if ($parts.Count -lt 2) { $client.Close(); continue }
    $method = $parts[0]
    $url = $parts[1]
    # consume headers
    while (($h = $reader.ReadLine()) -ne $null -and $h -ne '') { }

    $path = Resolve-FilePath -Root $RootPath -Relative $url -Spa:$SpaFallback
    if (Test-Path $path -PathType Leaf) {
      $body = [IO.File]::ReadAllBytes($path)
      $mime = Get-MimeType -Path $path
      $headers = "HTTP/1.1 200 OK`r`nContent-Type: $mime`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $hb = [Text.Encoding]::ASCII.GetBytes($headers)
      $stream.Write($hb,0,$hb.Length)
      $stream.Write($body,0,$body.Length)
    } else {
      $msg = "Not Found"
      $body = [Text.Encoding]::UTF8.GetBytes($msg)
      $headers = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
      $hb = [Text.Encoding]::ASCII.GetBytes($headers)
      $stream.Write($hb,0,$hb.Length)
      $stream.Write($body,0,$body.Length)
    }
  } catch {
    # ignore per-connection errors
  } finally {
    try { $stream.Close() } catch {}
    try { $client.Close() } catch {}
  }
}
