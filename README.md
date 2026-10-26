# claude-usage-timer-hook

Claude Code 를 쓰는 동안 일정 간격마다 화면 맨 위에 "Claude 실행 후 N분 경과했습니다." 알림을 띄우는 Windows 용 훅이에요.

- 알림은 화면 맨 위에 가로로 꽉 차게 뜨고, 문구가 오른쪽에서 왼쪽으로 한 번 흘러가면 사라져요.
- 포커스를 뺏지 않아서 작업 중이던 창은 그대로 유지돼요.
- 시간은 Claude 를 처음 켠 시점부터 마지막 Claude 가 종료될 때까지 재요. 여러 개를 켜도 시간이 겹치지 않고, `/resume`·`/clear` 를 해도 리셋되지 않아요.

## 요구 사항

- Windows 10 이상, PowerShell 5.1 (Windows 기본 `powershell.exe`)
- Claude Code

## 설치

1. `timer-notify.ps1` 을 `C:\Users\<사용자이름>\.claude\hooks\` 에 복사해요.
2. `settings.example.json` 의 `hooks` 부분을 `~/.claude/settings.json` 에 합쳐요. 경로의 `<사용자이름>` 은 본인 계정으로 바꿔요.
3. Claude Code 를 새로 시작해요.

## 설정

| 항목 | 위치 | 설명 |
|------|------|------|
| 알림 간격 | `settings.json` 의 `-Minutes` | 분 단위. 기본 60 |
| 막대 높이 | `timer-notify.ps1` 의 `Size($bounds.Width, 50)` | 픽셀 |
| 흐르는 속도 | `$label.Left -= 6` | 값이 클수록 빠름 |
| 글자 크기 | `Font('Malgun Gothic', 14, ...)` | pt |

## 동작 방식

- `SessionStart` 훅이 `claude.exe` 의 PID 를 `%TEMP%\claude-usage-timer\` 에 파일로 기록하고 타이머를 띄워요.
- 타이머는 뮤텍스(`ClaudeUsageTimer`)로 하나만 돌아요. 이미 돌고 있으면 새로 뜬 타이머는 바로 끝나요.
- 타이머는 2초마다 살아 있는 `claude.exe` 를 확인하고, 하나도 없으면 스스로 종료해요. 그래서 종료용 훅(`SessionEnd`)은 필요 없어요.

## 알아둘 점

- 문구의 분은 정수로 반올림돼요. 간격을 1분보다 짧게 하면 "0분 경과" 로 떠요 (테스트용 값).
- 한글이 깨지지 않도록 `timer-notify.ps1` 은 UTF-8 BOM 으로 저장돼 있어요. 편집기에서 BOM 을 지우지 않게 주의해요.
- 알림은 주 모니터 기준으로 떠요.
