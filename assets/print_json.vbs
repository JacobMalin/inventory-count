' 'Print Inven Sheet.vbs'
' 
' This file should print the inventory sheet single-sided when double clicked.
' 
' Written by Jacob Malin
' jacobmalin11@gmail.com
' Feel free to send me an email if it stops working

Dim fso, xlBook, xlApp, FilePath, SheetName, FileName, MacroName, MacroRunName

' Change these as nessesary
FilePath = "C:\~~~\Inven Sheet.xlsm"
MacroName = "Print_Single_Sided"
SheetName = "Sheet1"

' Get file name from file path
Set fso = CreateObject("Scripting.FileSystemObject")
FileName = fso.GetFileName(FilePath)

' Open Excel
Set xlApp = CreateObject("Excel.Application")

' Select workbook file
Set xlBook = xlApp.Workbooks.Open(FilePath, 0, true)

' Make workbook visible
xlApp.Visible = True

' Run macro that prints out single sided pages
MacroRunName = Replace(Replace("'{0}'!{1}", "{0}", FileName), "{1}", MacroName)
xlApp.Run MacroRunName, SheetName

' Close workbook and excel
xlBook.Close
xlApp.Quit

' Clean up
Set xlBook = Nothing
Set xlApp = Nothing



' ' Macro PrintModule.Print_Single_Sided
' '
' ' Prints each page seperately
' '
' ' Written by Jacob Malin
' ' jacobmalin11@gmail.com
' ' Feel free to send me an email if it stops working

' Dim PrintSheet, PageNum%, PageCount%

' Sub Print_Single_Sided(SheetName)
'     Set PrintSheet = Sheets(SheetName)

'     PageCount = PrintSheet.PageSetup.Pages.Count

'     For PageNum = 1 To PageCount
'         PrintSheet.PrintOut From:=PageNum, To:=PageNum, Preview:=True
'     Next PageNum

'     Set PrintSheet = Nothing
' End Sub