' MMBasic Daily Journal App
' Target: PicoCalc (320x320 Screen)
' Version 1.8 - Removed DIM for scalar variables as a test for "error dimensions"

OPTION EXPLICIT
OPTION DEFAULT NONE ' Force declaration of all variables
OPTION BASE 0       ' Arrays start at index 0

' *** Display Configuration Note ***
' The Lorenz example shows graphics working without OPTION LCDPANEL or MODE.
' This suggests your system defaults to the correct 320x320 graphics mode.
' Therefore, MODE 1 has been removed as it likely caused the error.
' The OPTION LCDPANEL line below might only be needed for initial setup
' or if you explicitly need to change display modes. For running this
' script, you can likely leave it commented out or remove it entirely
' if your default screen setup is correct.
' OPTION LCDPANEL Your_Display_Driver, Your_Parameters_Here 320, 320 ' <<< VERIFY IF NEEDED

' --- Constants ---
CONST TRUE = 1
CONST FALSE = 0
CONST MAX_LINES = 2000 ' Safety limit for lines, NOT pre-allocated size
CONST CTRL_S_CODE = 19 ' ASCII code for Ctrl+S (used with GETKEY)
CONST CTRL_X_CODE = 24 ' ASCII code for Ctrl+X (used with GETKEY)
' MM.KEY.F1 is a built-in constant, no need to declare

' --- Module-Level Variables (Global within this file) ---
DIM Entry$(0) AS STRING ' Declare array initially small, will be REDIMensioned

' --- Removed DIM for scalar variables below to test "error dimensions" ---
' --- If OPTION EXPLICIT requires them, errors will occur on first use ---
' DIM Filename$ AS STRING
' DIM CurrentDate$ AS STRING
' DIM LineCount AS INTEGER         ' <<< Formerly Line 28
' DIM NeedSave AS INTEGER          ' <<< Formerly Line 29

' --- Declare variables implicitly by assigning initial values ---
' --- This might satisfy OPTION EXPLICIT in some BASIC versions ---
DIM Filename$ AS STRING = "" ' Explicit DIM still preferred if allowed
DIM CurrentDate$ AS STRING = ""
DIM LineCount AS INTEGER = 0
DIM NeedSave AS INTEGER = FALSE ' Use FALSE (which is 0)

' --- Program Start ---

' 1. Check Date
CurrentDate$ = DATE$ ' First use assigns if DIM was removed
IF LEN(CurrentDate$) < 10 THEN
    CLS
    PRINT "Error: Invalid date format from system."
    PRINT "Expected MM/DD/YYYY, got: "; CurrentDate$
    DO : LOOP ' Halt
ENDIF

DIM Year AS INTEGER ' Local to the main execution block
Year = VAL(RIGHT$(CurrentDate$, 4))

IF Year < 2025 THEN
    CLS
    COLOUR 14, 4 ' Yellow on Red
    PRINT "System date seems incorrect (Year < 2025)."
    PRINT "Running date/time setup (onboot.bas)..."
    PAUSE 2000
    CLS
    ' Run setup script and then chain back to this journal script
    RUN "onboot.bas"
    RUN "journal.bas" ' Assumes this file is named journal.bas
    END ' End this instance gracefully
ENDIF

' 2. Construct Filename (YYYYMMDD.TXT)
Filename$ = DateToFilename$(CurrentDate$) + ".TXT" ' First use assigns if DIM was removed
' Check if date conversion failed
IF Filename$ = "INVALID_DATE.TXT" THEN
    CLS
    PRINT "Error: Could not create filename from date."
    PRINT "Date received: "; CurrentDate$
    DO : LOOP ' Halt
ENDIF


' 3. Load Existing Entry or Prepare New One
LoadJournalEntry() ' This will now dynamically size Entry$()

' 4. Main Interaction Loop
NeedSave = FALSE ' First use assigns if DIM was removed, otherwise resets to 0
DisplayLoop:
    CLS
    COLOUR 15, 1 ' White text on Blue background
    LOCATE 1, 1 : PRINT "MMBasic Daily Journal"
    LOCATE 2, 1 : PRINT "Date: "; CurrentDate$
    LOCATE 3, 1 : PRINT "File: "; Filename$
    IF NeedSave THEN LOCATE 4, 1 : PRINT "[ Unsaved Changes ]" : COLOUR 14, 1 ' Yellow indicator

    LOCATE 6, 1 : PRINT "---------------------------------"
    LOCATE 7, 1 : PRINT " F1: Edit Entry"
    LOCATE 8, 1 : PRINT " Ctrl+S: Save Entry"
    LOCATE 9, 1 : PRINT " Ctrl+X: Exit Journal"
    LOCATE 10, 1: PRINT "---------------------------------"

    ' Display preview (first few lines)
    LOCATE 12, 1 : PRINT "Preview:"
    DIM i AS INTEGER ' Local loop variable
    ' Check if array has elements before trying to access Entry$(0)
    IF LineCount > 0 THEN ' First use of LineCount if DIM was removed
        FOR i = 0 TO MIN(LineCount - 1, 10) ' Show up to 11 lines (0-10)
            LOCATE 13 + i, 1
            ' Check array bounds again just in case LineCount is wrong
            IF i <= UBOUND(Entry$) THEN
                 PRINT LEFT$(Entry$(i), HRES / 8 - 1) ' Print line, truncated
            ENDIF
        NEXT i
        IF LineCount > 11 THEN LOCATE 13 + 11, 1 : PRINT "..."
    ELSE
        LOCATE 13, 1 : PRINT "(New Entry)"
    ENDIF


    ' Wait for user input using GETKEY (returns numeric code)
    DIM K% AS INTEGER ' Local variable for key code
    K% = GETKEY ' Waits for a key press

    ' Process Input based on numeric key code
    SELECT CASE K%
        CASE MM.KEY.F1 ' Compare directly with built-in constant
            EditEntry()
            GOTO DisplayLoop ' Return to display after editing

        CASE CTRL_S_CODE ' Compare with Ctrl+S code
            SaveEntry()
            ' NeedSave flag is reset inside SaveEntry on success
            GOTO DisplayLoop ' Return to display after saving

        CASE CTRL_X_CODE ' Compare with Ctrl+X code
            IF NeedSave THEN
                CLS
                LOCATE 5, 1 : PRINT "You have unsaved changes!"
                LOCATE 7, 1 : PRINT "S = Save and Exit"
                LOCATE 8, 1 : PRINT "X = Exit WITHOUT Saving"
                LOCATE 9, 1 : PRINT "Any other key = Cancel"
                DIM ExitConfirmKey$ AS STRING ' Local variable for confirm key
                DO
                    ExitConfirmKey$ = UCASE$(INKEY$) ' Use INKEY$ here for single char
                LOOP UNTIL ExitConfirmKey$ <> ""
                SELECT CASE ExitConfirmKey$
                    CASE "S"
                        SaveEntry()
                        GOTO ExitApp
                    CASE "X"
                        GOTO ExitApp
                    CASE ELSE
                        GOTO DisplayLoop ' Cancel exit
                END SELECT
            ELSE
                GOTO ExitApp ' No unsaved changes, exit directly
            ENDIF

        CASE ELSE
            ' Ignore other keys
            GOTO DisplayLoop
    END SELECT

' --- End of Main Loop ---

ExitApp:
    CLS
    PRINT "Exiting Journal..."
    PAUSE 500
    CLS
END ' Terminate program


'-----------------------------------------
'      SUBROUTINES & FUNCTIONS
'-----------------------------------------

SUB LoadJournalEntry()
    ' Accesses module-level: Filename$, Entry$(), LineCount, NeedSave, MAX_LINES
    LOCAL FileNum AS INTEGER, TempLine$ AS STRING ' Local variables
    LineCount = 0
    REDIM Entry$(0) ' Start with a base 0 array (1 element size)

    ' Try to open the file for today
    ON ERROR GOTO FileDoesNotExist
    FileNum = FREEFILE
    OPEN Filename$ FOR INPUT AS #FileNum
    ON ERROR GOTO 0 ' Turn off error trapping

    ' Read lines, dynamically resizing the array
    WHILE NOT EOF(FileNum)
        LINE INPUT #FileNum, TempLine$
        IF LineCount = 0 THEN
            ' First line, replace the initial empty element
            Entry$(0) = TempLine$
        ELSE
            ' Subsequent lines, grow the array *before* assigning
            REDIM PRESERVE Entry$(LineCount) ' Increase upper bound to LineCount
            Entry$(LineCount) = TempLine$    ' Assign to the new element
        ENDIF
        LineCount = LineCount + 1

        ' Check if we hit the safety limit
        IF LineCount >= MAX_LINES THEN
            PRINT "Warning: Maximum lines ("; MAX_LINES; ") reached."
            PRINT "File loading truncated."
            PAUSE 2000
            EXIT WHILE
        ENDIF
    WEND
    CLOSE #FileNum

    ' Handle case where file existed but was empty, or only contained blank lines
    ' that might have been skipped or resulted in LineCount = 0
    IF LineCount = 0 THEN
         REDIM Entry$(0) ' Ensure array exists with one element
         Entry$(0) = ""
         LineCount = 1 ' Treat as one empty line for editor
    ENDIF
    ' Array is now sized correctly based on lines read (up to MAX_LINES)
    EXIT SUB

FileDoesNotExist:
    ' File not found, it's a new entry. Array already REDIM'd to Entry$(0)
    ON ERROR GOTO 0 ' Turn off error trapping
    Entry$(0) = "" ' Ensure the single element is empty
    LineCount = 1
    NeedSave = TRUE ' Mark as needing save immediately
END SUB

'-----------------------------------------

SUB EditEntry()
    ' Accesses module-level: Entry$(), LineCount, NeedSave
    ' Uses built-in: CLS, COLOUR, EDIT, UBOUND
    CLS
    COLOUR 15, 1 ' White on Blue for editor consistency
    ' Ensure array has at least one element before editing
    IF UBOUND(Entry$) < 0 THEN REDIM Entry$(0)
    EDIT Entry$() ' Edit the array directly
    ' After EDIT exits (ESC or Ctrl+C), update line count and set save flag
    LineCount = UBOUND(Entry$) + 1
    NeedSave = TRUE
    ' Control returns to the main loop after this SUB finishes
END SUB

'-----------------------------------------

SUB SaveEntry()
    ' Accesses module-level: Filename$, Entry$(), LineCount, NeedSave
    LOCAL FileNum AS INTEGER, i AS INTEGER ' Local variables
    CLS
    LOCATE 5, 5 : PRINT "Saving entry to "; Filename$; "..."

    ON ERROR GOTO SaveError
    FileNum = FREEFILE
    OPEN Filename$ FOR OUTPUT AS #FileNum
    ON ERROR GOTO 0 ' Disable error trap

    ' Write each line from the array to the file
    ' Ensure LineCount is valid before looping
    IF LineCount > 0 THEN
        FOR i = 0 TO LineCount - 1
             ' Check bounds just in case
             IF i <= UBOUND(Entry$) THEN PRINT #FileNum, Entry$(i)
        NEXT i
    ENDIF
    CLOSE #FileNum

    LOCATE 7, 5 : PRINT "Entry saved successfully."
    NeedSave = FALSE ' Clear flag after successful save
    PAUSE 1500
    EXIT SUB

SaveError:
    ON ERROR GOTO 0 ' Disable error trap
    IF FileNum > 0 THEN CLOSE #FileNum ' Attempt to close file if open
    LOCATE 7, 5 : PRINT "ERROR SAVING FILE!"
    LOCATE 8, 5 : PRINT ERRormsg$ ' Display MMBasic error message
    PAUSE 3000
    ' Do not clear NeedSave flag on error
END SUB

'-----------------------------------------

FUNCTION DateToFilename$(D$) AS STRING
    ' Accesses built-in string functions
    LOCAL M$, Dy$, Y$ ' Local variables
    IF LEN(D$) = 10 THEN
        M$ = LEFT$(D$, 2)
        Dy$ = MID$(D$, 4, 2)
        Y$ = RIGHT$(D$, 4)
        ' Assign return value to the function name
        DateToFilename$ = Y$ + M$ + Dy$
    ELSE
        ' Assign return value to the function name
        DateToFilename$ = "INVALID_DATE" ' Return error string if format is wrong
    ENDIF
END FUNCTION

'-----------------------------------------

