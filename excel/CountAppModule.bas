' Macro CountAppModule.Print_From_Json
'
' Takes a count json and prints it single sided
'
' Written by Jacob Malin
' jacobmalin11@gmail.com
' Feel free to send me an email if it stops working

Function Print_From_Json(Json)
    On Error GoTo HandleFailure

    Dim SheetName: SheetName = "First Draft"
    Dim PrintSheet: Set PrintSheet = Sheets(SheetName)
    
    Dim PrintArea: PrintArea = PrintSheet.PageSetup.PrintArea
    
    Dim GroupName, SecondGroupName, ItemName
    For Each Row In PrintSheet.Range(PrintArea).Rows
        If Not IsEmpty(Row.Cells(3).Value) Then
            If Row.Cells(3).Value <> "Small" And Row.Cells(3).Value <> "Large" Then
                GroupName = Row.Cells(3).Value
                SecondGroupName = Empty
            Else
                SecondGroupName = Row.Cells(3).Value
            End If
        End If
            
        If Not IsEmpty(Row.Cells(4).Value) And Json.Exists(GroupName) Then
            ItemName = Row.Cells(4).Value
            
            If Not IsEmpty(SecondGroupName) Then
                ItemName = SecondGroupName & " " & ItemName
            End If
            
            If Not Json(GroupName).Exists(ItemName) Then
                For Each Key In Json(GroupName).keys
                    If InStr(1, Key, ItemName) = 1 Then
                        ItemName = Key
                        Exit For
                    End If
                Next Key
            End If
            
            If Json(GroupName).Exists(ItemName) Then
                If Json(GroupName)(ItemName).Exists("Back") Then
                    Row.Cells(5).Value = Json(GroupName)(ItemName)("Back")
                    Row.Cells(5).HorizontalAlignment = xlCenter
                End If
                If Json(GroupName)(ItemName).Exists("Cabinet") Then
                    Row.Cells(6).Value = Json(GroupName)(ItemName)("Cabinet")
                    Row.Cells(6).HorizontalAlignment = xlCenter
                End If
                If Json(GroupName)(ItemName).Exists("Out") Then
                    Row.Cells(7).Value = Json(GroupName)(ItemName)("Out")
                    Row.Cells(7).HorizontalAlignment = xlCenter
                End If
                If Json(GroupName)(ItemName).Exists("Total") Then
                    Row.Cells(9).Value = Json(GroupName)(ItemName)("Total")
                    Row.Cells(9).HorizontalAlignment = xlCenter
                End If
                If Json(GroupName)(ItemName).Exists("Damaged") Then
                    Row.Cells(11).Value = Json(GroupName)(ItemName)("Damaged")
                    Row.Cells(11).HorizontalAlignment = xlLeft
                End If
                If Json(GroupName)(ItemName).Exists("Expected") Then
                    Dim expectedDiff
                    expectedDiff = Json(GroupName)(ItemName)("Total") - Json(GroupName)(ItemName)("Expected")

                    If expectedDiff <> 0 Then
                        Row.Cells(12).Value = expectedDiff
                        Row.Cells(12).HorizontalAlignment = xlLeft
                    End If
                End If
            End If
        End If
    Next Row
    
    Print_From_Json = Print_Single_Sided(SheetName)
    Exit Function

HandleFailure:
    Print_From_Json = "failed: " & Err.Description
End Function


