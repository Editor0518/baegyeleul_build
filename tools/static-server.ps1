param(
    [int]$Port = 8000,
    [string]$RootPath = (Join-Path $PSScriptRoot 'visual-novel-out'),
    [switch]$SpaFallback
)

Add-Type -AssemblyName System.Net
$listener = [System.Net.HttpListener]::new()
$prefix = "http://localhost:$Port/"
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Host "Serving $RootPath at $prefix"
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($rel)) { $rel = "index.html" }
    $path = Join-Path $RootPath $rel

    if (Test-Path $path -PathType Container) {
        $path = Join-Path $path "index.html"
    }

    if (-not (Test-Path $path -PathType Leaf) -and $SpaFallback.IsPresent) {
        $path = Join-Path $RootPath "index.html"
    }

    if (Test-Path $path -PathType Leaf) {
        $ext = [IO.Path]::GetExtension($path).ToLowerInvariant()
        $mime = switch ($ext) {
          ".html" { "text/html" }
          ".htm"  { "text/html" }
          ".css"  { "text/css" }
          ".js"   { "application/javascript" }
          ".json" { "application/json" }
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
        $bytes = [System.IO.File]::ReadAllBytes($path)
        $res.ContentType = $mime
        $res.ContentLength64 = $bytes.Length
        $res.StatusCode = 200
        $res.OutputStream.Write($bytes,0,$bytes.Length)
    } else {
        $res.StatusCode = 404
    }
    $res.OutputStream.Close()
  }
} finally {
  $listener.Stop()
}
