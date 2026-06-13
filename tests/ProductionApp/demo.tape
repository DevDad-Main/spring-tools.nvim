Output demo.gif

Set Width 1200
Set Height 800
Set FontSize 14
Set FontFamily "JetBrainsMono Nerd Font Mono"
Set Framerate 10

Sleep 1s
Type "cd tests/ProductionApp"
Enter
Sleep 500ms
Type "nvim ."
Enter
Sleep 2s

# Show sidebar with :SpringBoot
Type ":"
Sleep 200ms
Type "SpringBoot"
Sleep 500ms
Enter
Sleep 3s

# Navigate to logs
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Type "j"
Sleep 500ms
Enter
Sleep 500ms
Type "j"
Sleep 200ms
Type "j"
Sleep 200ms
Enter
Sleep 3s

# Switch to Endpoints tab
Type "4"
Sleep 500ms

# Switch to Config tab
Type "5"
Sleep 500ms

# Switch to Tests tab
Type "3"
Sleep 1s

# Switch back to Dashboard
Type "1"
Sleep 1s

# Run a custom command
Type "j"
Sleep 200ms
Type "Enter"
Sleep 500ms
Type "j"
Sleep 300ms
Enter
Sleep 1s
Type "mvn clean compile"
Enter
Sleep 5s

# Quit
Type ":"
Sleep 200ms
Type "qa"
Enter
