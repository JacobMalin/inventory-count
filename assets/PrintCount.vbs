' 'PrintCount.vbs'
' 
' This file should print the inventory sheet single-sided given a count json.
' 
' Written by Jacob Malin
' jacobmalin11@gmail.com
' Feel free to send me an email if it stops working

if WScript.Arguments.Count < 2 Then
    WScript.Echo "Usage: cscript Print_Inven_Sheet.vbs <VbsJson.vbs Path> <Excel File Path> <Count JSON Path>"
    WScript.Quit 1
End If

' Change these as nessesary
Dim VbsJsonPath : VbsJsonPath = WScript.Arguments(0)
Dim ExcelFilePath : ExcelFilePath = WScript.Arguments(1)
Dim CountJsonPath : CountJsonPath = WScript.Arguments(2)
Dim MacroName : MacroName = "Print_From_Json"

' Function to include and execute another VBScript file
Sub includeFile(fSpec)
    With CreateObject("Scripting.FileSystemObject")
        ExecuteGlobal .openTextFile(fSpec).readAll()
    End With
End Sub

' Load ScriptControl for JSON parsing
includeFile VbsJsonPath
Dim json : Set json = New VbsJson

' Create FileSystemObject
Dim fso : Set fso = CreateObject("Scripting.FileSystemObject")

' Open Excel
Dim FileName : FileName = fso.GetFileName(ExcelFilePath)
Dim xlApp : Set xlApp = CreateObject("Excel.Application")
Dim xlBook : Set xlBook = xlApp.Workbooks.Open(ExcelFilePath, 0, true)

' Make workbook visible
' xlApp.Visible = True

' Read JSON file and validate it, then pass the JSON text to the macro
If Not fso.FileExists(CountJsonPath) Then
    xlBook.Close False
    xlApp.Quit

    Set fso = Nothing
    Set json = Nothing
    Set xlApp = Nothing
    Set xlBook = Nothing

    WScript.Quit 1
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
    WScript.Echo "Failed to parse JSON: " & Err.Description
    Err.Clear
End If
On Error GoTo 0

' Run macro that prints out single sided pages and pass JSON text as argument
Dim MacroRunName : MacroRunName = Replace(Replace("'{0}'!{1}", "{0}", FileName), "{1}", MacroName)
xlApp.Run MacroRunName, JsonParsed

' Close workbook and excel
xlBook.Close False
xlApp.Quit

' Clean up
Set fso = Nothing
Set json = Nothing
Set xlApp = Nothing
Set xlBook = Nothing