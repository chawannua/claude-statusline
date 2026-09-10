param(
    [Parameter(ValueFromPipeline=$true)]
    [string]$InputJson
)

if (-not $InputJson) {
    if ($args.Count -gt 0) {
        $InputJson = $args[0]
    } else {
        exit
    }
}

try {
    $data = $InputJson | ConvertFrom-Json
} catch {
    exit
}

$ESC = [char]27
$Reset = "$ESC[0m"
$Bold = "$ESC[1m"

$White = "$ESC[38;2;220;225;230m"
$Frost = "$ESC[38;2;143;188;187m"
$Slate = "$ESC[38;2;110;125;140m"
$Dark = "$ESC[38;2;76;86;106m"

$Model = $data.model
$Cwd = $data.cwd
$Cost = $data.cost
$Context = $data.context_window
$Rate = $data.rate_limits

$Sep = " ${Dark}?${Reset} "

$output = ""
if ($Cwd) { $output += "${Slate}$Cwd$Reset$Sep" }
if ($Model) { $output += "${White}${Bold}$Model$Reset$Sep" }
if ($Cost) {
    $costStr = "${Frost}`$$($Cost.total_cost_usd)$Reset (${Slate}$($Cost.total_duration_ms)ms$Reset)"
    $output += "$costStr$Sep"
}
if ($Context) { $output += "${Frost}Ctx: ${Slate}$Context$Reset$Sep" }
if ($Rate) { $output += "${Frost}Limit: ${Slate}$($Rate.spend_limit)$Reset" }

if ($output.EndsWith($Sep)) {
    $output = $output.Substring(0, $output.Length - $Sep.Length)
}

Write-Host "$output" -NoNewline
