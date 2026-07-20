on run argv
    set volumeName to item 1 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set pathbar visible of container window to false
            set sidebar width of container window to 0
            set the bounds of container window to {100, 100, 1300, 800}

            set viewOptions to the icon view options of container window
            set arrangement of viewOptions to not arranged
            set icon size of viewOptions to 112
            set text size of viewOptions to 14
            set background picture of viewOptions to file ".background:dmg-background.png"

            set position of item "Notch.app" of container window to {400, 365}
            set position of item "Applications" of container window to {800, 365}

            try
                set position of item ".background" of container window to {1600, 1100}
            end try
            try
                set position of item ".fseventsd" of container window to {1750, 1100}
            end try

            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
