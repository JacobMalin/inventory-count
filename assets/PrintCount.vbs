' 'PrintCount.vbs'
' 
' This file should print the inventory sheet single-sided given a count json.
' 
' Written by Jacob Malin
' jacobmalin11@gmail.com
' Feel free to send me an email if it stops working

If WScript.Arguments.Count < 3 Then
    WScript.Echo "Usage: cscript Print_Inven_Sheet.vbs <VbsJson.vbs Path> <Excel File Path> <Count JSON Path>"
    WScript.Quit 1
End If

' Change these as nessesary
Dim VbsJsonPath : VbsJsonPath = WScript.Arguments(0)
Dim ExcelFilePath : ExcelFilePath = WScript.Arguments(1)
Dim CountJsonPath : CountJsonPath = WScript.Arguments(2)
Dim MacroName : MacroName = "Print_From_Json"
Dim JsonText

Dim fso
Dim json
Dim xlApp
Dim xlBook

Sub EmitStatus(status, message)
    WScript.Echo "IC_PRINT_STATUS|" & status & "|" & Replace(Replace(message, vbCr, " "), vbLf, " ")
End Sub

Sub Cleanup()
    On Error Resume Next

    If Not xlBook Is Nothing Then
        xlBook.Close False
        Set xlBook = Nothing
    End If

    If Not xlApp Is Nothing Then
        xlApp.Quit
        Set xlApp = Nothing
    End If

    If Not fso Is Nothing Then
        Set fso = Nothing
    End If

    If Not json Is Nothing Then
        Set json = Nothing
    End If

    On Error GoTo 0
End Sub

' Function to include and execute another VBScript file
Sub includeFile(fSpec)
    With CreateObject("Scripting.FileSystemObject")
        ExecuteGlobal .openTextFile(fSpec).readAll()
    End With
End Sub

' Load ScriptControl for JSON parsing
includeFile VbsJsonPath
Set json = New VbsJson

' Create FileSystemObject
Set fso = CreateObject("Scripting.FileSystemObject")

If Not fso.FileExists(ExcelFilePath) Then
    EmitStatus "failed", "Excel file not found: " & ExcelFilePath
    Cleanup
    WScript.Quit 2
End If

' Open Excel
Dim FileName : FileName = fso.GetFileName(ExcelFilePath)
Set xlApp = CreateObject("Excel.Application")

On Error Resume Next
Set xlBook = xlApp.Workbooks.Open(ExcelFilePath, 0, true)
If Err.Number <> 0 Then
    EmitStatus "failed", "Failed to open Excel workbook: " & Err.Description
    Err.Clear
    On Error GoTo 0
    Cleanup
    WScript.Quit 2
End If
On Error GoTo 0

' Make workbook visible
' xlApp.Visible = True

' Read JSON file and validate it, then pass the JSON text to the macro
If Not fso.FileExists(CountJsonPath) Then
    EmitStatus "failed", "Count JSON file not found: " & CountJsonPath
    Cleanup
    WScript.Quit 2
End If

    
Dim oStreamUTF8 : Set oStreamUTF8 = CreateObject("ADODB.Stream")
With oStreamUTF8
    .Charset = "UTF-8"
    .Type = 2 'adTypeText
    .Open
    .LoadFromFile CountJsonPath
    JsonText = .ReadText
    .Close
End With
Set oStreamUTF8 = Nothing

' Try to parse JSON using the JScript engine for validation
On Error Resume Next
Dim JsonParsed : Set JsonParsed = json.Decode(JsonText)
If Err.Number <> 0 Then
    EmitStatus "failed", "Failed to parse JSON: " & Err.Description
    Err.Clear
    On Error GoTo 0
    Cleanup
    WScript.Quit 2
End If
On Error GoTo 0

' Run macro that prints out single sided pages and pass JSON text as argument
Dim MacroRunName : MacroRunName = Replace(Replace("'{0}'!{1}", "{0}", FileName), "{1}", MacroName)
Dim runResult

On Error Resume Next
runResult = xlApp.Run(MacroRunName, JsonParsed)
If Err.Number <> 0 Then
    EmitStatus "failed", "Excel macro failed: " & Err.Description
    Err.Clear
    On Error GoTo 0
    Cleanup
    WScript.Quit 2
End If
On Error GoTo 0

Dim runResultText : runResultText = LCase(CStr(runResult))

If VarType(runResult) = vbBoolean And runResult = False Then
    EmitStatus "cancelled", "Print cancelled by macro."
    Cleanup
    WScript.Quit 0
End If

If InStr(runResultText, "cancel") > 0 Then
    EmitStatus "cancelled", CStr(runResult)
    Cleanup
    WScript.Quit 0
End If

If InStr(runResultText, "fail") > 0 Or InStr(runResultText, "error") > 0 Then
    EmitStatus "failed", CStr(runResult)
    Cleanup
    WScript.Quit 2
End If

EmitStatus "completed", "Print macro completed."

Cleanup
WScript.Quit 0