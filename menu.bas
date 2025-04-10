'----------------------------------------------------
' MMBasic Scrollable Menu Browser with Directory Navigation
' Supports up to 100 items per directory, 25 lines visible at a time.
' Directories are flagged as "D" and .BAS files as "F".
' Navigation is via up (asc=128) and down (asc=129) arrows.
' ENTER (asc=10) selects the highlighted item.
'----------------------------------------------------

maxVisible = 25      ' Number of lines visible on screen
maxItems   = 100     ' Maximum number of items in a directory

dim file$(maxItems)         ' Array of filenames or directory names
dim fileType$(maxItems)     ' "D" for Directory, "F" for .BAS File

' Global variables:
currentDir$ = "B:\"   ' Starting directory (adjust as needed)
totalItems = 0        ' Total items loaded in current directory
sel = 1               ' Current selection index (1 to totalItems)
offset = 1            ' First item displayed (for scrolling)

'----------------------------------------------------
' INITIALIZATION: Set drive and change to starting directory
Drive "B:"
ChDir currentDir$

'----------------------------------------------------
' LOAD DIRECTORY (using goto rather than a subroutine)
goto LoadDir

LoadDir:
    totalItems = 0
    ' Initialize the arrays:
    for i = 1 to maxItems
         file$(i) = ""
         fileType$(i) = ""
    next i

    ' If not at root, add a parent directory option ("..")
    if currentDir$ <> "B:\" then
         totalItems = totalItems + 1
         file$(totalItems) = ".."
         fileType$(totalItems) = "D"
    end if

    ' Load directories first:
    d$ = Dir$("*", DIR)
    do while d$ <> ""
         if d$ <> "." and d$ <> ".." then
             totalItems = totalItems + 1
             if totalItems > maxItems then goto SkipFiles
             file$(totalItems) = d$
             fileType$(totalItems) = "D"
         end if
         d$ = Dir$()
    loop
SkipFiles:
    ' Load .BAS files:
    f$ = Dir$("*.bas", FILE)
    do while f$ <> ""
         totalItems = totalItems + 1
         if totalItems > maxItems then exit do
         file$(totalItems) = f$
         fileType$(totalItems) = "F"
         f$ = Dir$()
    loop

    ' Reset selection and scroll for the new directory:
    sel = 1
    offset = 1
    goto DisplayList

'----------------------------------------------------
' DISPLAY LIST: show up to maxVisible lines
DisplayList:
    cls
    print "Current Directory: "; currentDir$
    print ""
    for i = 1 to maxVisible
         idx = offset + i - 1
         if idx > totalItems then exit for
         if idx = sel then
              color rgb(black), rgb(lightgray)  ' Highlight selected (inverted)
         else
              color rgb(lightgray), rgb(black)
         end if
         print file$(idx)
    next i
    color rgb(lightgray), rgb(black)
    goto MainLoop

'----------------------------------------------------
' MAIN LOOP: Waits for key input and updates selection or exits
MainLoop:
    a$ = inkey$
    if a$ = "" then goto MainLoop

    ' Check if ENTER was pressed (assume asc(a$)=10 means ENTER)
    if asc(a$) = 10 then goto SelectedItem

    previ = sel

    ' Process arrow keys for navigation:
    if asc(a$) = 129 then sel = sel + 1   ' Arrow down
    if asc(a$) = 128 then sel = sel - 1   ' Arrow up

    ' Wrap selection around:
    if sel < 1 then sel = totalItems
    if sel > totalItems then sel = 1

    ' Adjust scrolling to keep the selected item visible:
    if sel < offset then offset = sel
    if sel > offset + maxVisible - 1 then offset = sel - maxVisible + 1

    goto DisplayList

'----------------------------------------------------
' SELECTED ITEM: Process the currently highlighted item
SelectedItem:
    cls
    selectedName$ = file$(sel)
    selectedType$ = fileType$(sel)

    if selectedType$ = "D" then
         ' If directory, change directory:
         if selectedName$ = ".." then
              ChDir ".."
         else
              ChDir selectedName$
         end if
         currentDir$ = CURDIR$
         goto LoadDir    ' Reload new directory listing
    else if selectedType$ = "F" then
         ' If file, run the .BAS program:
         run selectedName$
    end if

    goto MainLoop

