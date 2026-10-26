param(
    [ValidateSet('start', 'run')]
    [string]$Mode = 'start',
    [double]$Minutes = 60
)

# claude.exe PID 마다 파일 하나. /resume·/clear 는 같은 프로세스라 파일이 그대로다
$SessionDir = Join-Path $env:TEMP 'claude-usage-timer'

function Get-ClaudePid {
    # 훅은 claude.exe 의 자손으로 뜨므로 부모를 거슬러 올라가 찾는다
    $id = $PID
    while ($id) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$id"
        if (-not $p) { return $null }
        if ($p.Name -eq 'claude.exe') { return $p.ProcessId }
        $id = $p.ParentProcessId
    }
}

function Get-LiveClaudeCount {
    # 비정상 종료로 남은 파일도 여기서 걸러낸다 (PID 재사용 대비해 이름도 확인)
    $n = 0
    Get-ChildItem $SessionDir -ErrorAction SilentlyContinue | ForEach-Object {
        $proc = Get-Process -Id $_.Name -ErrorAction SilentlyContinue
        if ($proc -and $proc.ProcessName -eq 'claude') { $n++ }
        else { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
    }
    $n
}

function Show-Toast([string]$Text) {
    # 포커스를 뺏지 않고 띄우기 위해 ShowWithoutActivation 을 켠 폼
    if (-not ('ToastForm' -as [type])) {
        Add-Type -ReferencedAssemblies System.Windows.Forms -TypeDefinition @'
using System.Windows.Forms;
public class ToastForm : Form {
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams {
        get {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            return cp;
        }
    }
}
'@
    }

    $form = New-Object ToastForm
    $form.FormBorderStyle = 'None'
    # 화면 맨 위에 가로로 꽉 차게 띄운다
    $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $form.StartPosition = 'Manual'
    $form.Location = New-Object System.Drawing.Point($bounds.X, $bounds.Y)
    $form.Size = New-Object System.Drawing.Size($bounds.Width, 50)
    $form.TopMost = $true
    $form.ShowInTaskbar = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 46)

    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.AutoSize = $true
    $label.ForeColor = [System.Drawing.Color]::White
    $label.Font = New-Object System.Drawing.Font('Malgun Gothic', 14, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($label)

    # 오른쪽 화면 밖에서 시작해 왼쪽으로 흘러가고, 끝까지 지나가면 닫는다
    $label.Location = New-Object System.Drawing.Point($form.Width, [int](($form.Height - $label.Height) / 2))

    $form.Add_Click({ $form.Close() })
    $label.Add_Click({ $form.Close() })

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 16
    $timer.Add_Tick({
        $label.Left -= 6
        if ($label.Right -lt 0) { $timer.Stop(); $form.Close() }
    })
    $timer.Start()

    [System.Media.SystemSounds]::Asterisk.Play()
    [void]$form.ShowDialog()
}

switch ($Mode) {
    'start' {
        $claudePid = Get-ClaudePid
        if (-not $claudePid) { return }
        New-Item -ItemType Directory -Force $SessionDir | Out-Null
        New-Item -ItemType File -Force (Join-Path $SessionDir $claudePid) | Out-Null
        # 타이머는 하나만 돈다. 이미 돌고 있으면 run 쪽에서 뮤텍스를 못 잡고 바로 끝난다
        Start-Process powershell -WindowStyle Hidden -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass',
            '-File', "`"$PSCommandPath`"", '-Mode', 'run', '-Minutes', $Minutes
        )
    }
    'run' {
        $mutex = New-Object System.Threading.Mutex($false, 'ClaudeUsageTimer')
        if (-not $mutex.WaitOne(0)) { return }
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $n = 0
        $start = Get-Date
        while ($true) {
            # 토스트가 떠 있던 시간만큼 밀리지 않도록 시작 시각 기준 목표 시각까지만 잔다
            $n++
            $target = $start.AddMinutes($Minutes * $n)
            while ((Get-Date) -lt $target) {
                # 마지막 Claude 가 종료되면 타이머도 끝낸다
                if ((Get-LiveClaudeCount) -eq 0) { return }
                Start-Sleep -Seconds 2
            }
            Show-Toast ("Claude 실행 후 {0}분 경과했습니다." -f [math]::Round($Minutes * $n))
        }
    }
}
