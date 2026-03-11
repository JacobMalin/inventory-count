Attribute VB_Name = "PrintModule"
' Macro PrintModule.Print_Single_Sided
'
' Prints each page seperately
'
' Written by Jacob Malin
' jacobmalin11@gmail.com
' Feel free to send me an email if it stops working

Dim PrintSheet, PageNum%, PageCount%

Function Print_Single_Sided(SheetName)
    On Error GoTo HandleFailure

    Set PrintSheet = Sheets(SheetName)

    PageCount = PrintSheet.PageSetup.Pages.Count

    For PageNum = 1 To PageCount
        PrintSheet.PrintOut From:=PageNum, To:=PageNum
    Next PageNum

    Print_Single_Sided = "completed"
    Set PrintSheet = Nothing
    Exit Function

HandleFailure:
    If InStr(1, LCase(Err.Description), "cancel", vbTextCompare) > 0 Then
        Print_Single_Sided = "cancelled"
    Else
        Print_Single_Sided = "failed: " & Err.Description
    End If
    Set PrintSheet = Nothing
End Function
