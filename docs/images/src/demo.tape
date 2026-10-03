# Source for the terminal part of docs/images/demo.gif.
# Render: vhs docs/images/src/demo.tape  (then compose with demo.sh)
# Runs only --dry-run against a throwaway state dir, so nothing on the machine changes.

Output build/demo-term.mp4

Set Shell zsh
Set FontFamily "Menlo"
Set FontSize 25
Set Width 1520
Set Height 868
Set Padding 44
Set Margin 0
Set WindowBar Colorful
Set WindowBarSize 64
Set BorderRadius 0
Set TypingSpeed 45ms
Set Framerate 24
Set Theme { "name": "llm-mode", "black": "#0b0b0c", "red": "#ff5a1a", "green": "#7ee2a8", "yellow": "#ffb86b", "blue": "#8ab4ff", "magenta": "#d7a6ff", "cyan": "#7fd8e6", "white": "#e8e8ea", "brightBlack": "#6b6b73", "brightRed": "#ff7a45", "brightGreen": "#9cf0c0", "brightYellow": "#ffd08f", "brightBlue": "#a8c6ff", "brightMagenta": "#e4c2ff", "brightCyan": "#a5e8f2", "brightWhite": "#ffffff", "background": "#141416", "foreground": "#e8e8ea", "selection": "#2a2a2e", "cursor": "#ff5a1a" }

Hide
Type "export LLM_MODE_DIR=$HOME/.llm-mode-demo PS1='%F{#ff5a1a}❯%f ' && rm -rf $LLM_MODE_DIR && clear"
Enter
Sleep 500ms
Show

Sleep 600ms
Type "llm-mode on --dry-run"
Sleep 400ms
Enter
Sleep 3.5s

Type "llm-mode off --dry-run"
Sleep 400ms
Enter
Sleep 4s

Hide
Type "rm -rf $LLM_MODE_DIR"
Enter
