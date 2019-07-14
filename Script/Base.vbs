Option Explicit

' Declare global variables.
Dim vWScriptShell
Dim vFileSystemObject

' Initialize the wscript shell external object.
Set vWScriptShell = CreateObject("WScript.Shell")

' Initialize the file system object external object.
Set vFileSystemObject = CreateObject("Scripting.FileSystemObject")

' Define external object constants.
Const fsoForReading = 1
Const xlOpenXMLWorkbookMacroEnabled = 52
Const xlMaximized = -4137

' Define internal class constants.
Const vClsListInitialArraySize = 32
Const vClsListResizeThreshold = 0.25
Const vClsListResizeFactor = 2

Class ClsList
	' Declare local variables.
	Private vArray()
	Private vArraySize
	Private vCount

	Private Sub Class_Initialize()
		' Set the underlying array size.
		vArraySize = vClsListInitialArraySize

		' Initialize the underlying array.
		Redim vArray(vArraySize - 1)

		' Set the actual item count.
		vCount = 0
	End Sub

	Public Property Get Count()
		' Return the actual item count.
		Count = vCount
	End Property

	Private Property Let Count( _
		vNewCount _
	)
		vCount = vNewCount
	End Property

	Public Function Add( _
		vValue _
	)
		' Enlarge the underlying array if needed.
		If (Count / vArraySize) > (1 - vClsListResizeThreshold) Then
			vArraySize = vArraySize * vClsListResizeFactor
			Redim Preserve vArray(vArraySize - 1)
		End If

		' Increment the item count.
		Count = Count + 1

		' Store the new value after the last populated value of the underlying array.
		Set vArray(Count - 1) = vValue

		' Return the current instance for chaining.
		Set Add = Me
	End Function

	Public Function Remove()
		' Shrink the underlying array if needed.
		If (vClsListInitialArraySize < vArraySize) And ((Count / vArraySize) < vClsListResizeThreshold) Then
			vArraySize = Round(vArraySize / vClsListResizeFactor + 0.5)
			Redim Preserve vArray(vArraySize - 1)
		End If

		' Decrement the item count.
		Count = Count - 1

		' Return the current instance for chaining.
		Set Remove = Me
	End Function

	Public Property Get Item( _
		vIndex _
	)
		' Verify that the list boundaries are not exceeded.
		If (0 <= vIndex) Or (vIndex < Count) Then
			' Return the value at the corresponding index in the underlying array.
			Item = vArray(vIndex)
		Else
			' Return null.
			Item = Null
		End If
	End Property

	Public Property Let Item( _
		vIndex, _
		vValue _
	)
		' Verify that the list boundaries are not exceeded.
		If (0 <= vIndex) Or (vIndex < Count) Then
			' Set the value at the corresponding index in the underlying array.
			vArray(vIndex) = vValue
		End If
	End Property

	Public Function Items()
		' Declare local variables.
		Dim vItems()
		Dim vIndex

		' Resize the result array to hold all of the list's items and no more.
		Redim vItems(Count - 1)

		' Copy each of the values from the underlying array to the result array.
		For vIndex = 0 To Count - 1
			Set vItems(vIndex) = vArray(vIndex)
		Next

		' Return the result array.
		Items = vItems
	End Function
End Class

Class ClsSet
	' Declare local variables.
	Dim vDictionary

	Private Sub Class_Initialize()
		' Initialize the underlying dictionary.
		Set vDictionary = CreateObject("Scripting.Dictionary")
	End Sub

	Public Property Get Count()
		' Return the count value from the underlying dictionary.
		Count = vDictionary.Count
	End Property

	Public Function Add( _
		vValue _
	)
		' Verify that the value does not already exist in the set.
		If Not Exists(vValue) Then
			' Add to the underlying dictionary.
			Call vDictionary.Add(vValue, Null)
		End If

		' Return the current instance for chaining.
		Set Add = Me
	End Function

	Public Function Remove( _
		vValue _
	)
		' Remove from the underlying dictionary.
		Call vDictionary.Remove(vValue)

		' Return the current instance for chaining.
		Set Remove = Me
	End Function

	Public Function Exists( _
		vValue _
	)
		' Check in the underlying dictionary.
		Exists = vDictionary.Exists(vValue)
	End Function

	Public Function Items()
		' Return the keys from the underlying dictionary.
		Items = vDictionary.Keys()
	End Function
End Class

Function ReadTextFile( _
	vFilePath _
)
	' Open the specified text file in ascii read mode, without creating it.
	With vFileSystemObject.OpenTextFile(vFilePath, fsoForReading, False)
		' Read and return all of the file's content.
		ReadTextFile = .ReadAll()

		' Close the text file.
		Call .Close
	End With
End Function

Sub WriteTextFile( _
	vFilePath, _
	vContent _
)
	' Create the specified text file in ascii read mode, without creating it.
	With vFileSystemObject.CreateTextFile(vFilePath)
		' Write all of the submitted content.
		Call .Write(vContent)

		' Close the text file.
		Call .Close
	End With
End Sub

Function GetLocalProjectDirectoryPath()
	GetLocalProjectDirectoryPath = vFileSystemObject.GetParentFolderName(vFileSystemObject.GetParentFolderName(WScript.ScriptFullName))
End Function

Function LoadBuildConfiguration( _
	vFilePath _
)
	' Declare local variables.
	Dim vList
	Dim vChildNode
	Dim vItem
	Dim vSet

	' Initialize the msxml dom document object.
	With CreateObject("MSXML2.DOMDocument.6.0")
		' Configure to load files asynchronously.
		.async = False

		' Load the build configuration xml file.
		Call .load(vFilePath)

		' Initialize the result.
		Set LoadBuildConfiguration = CreateObject("Scripting.Dictionary")

		' Load the root xml node.
		With .selectSingleNode("build")
			' Load the project's name.
			Call LoadBuildConfiguration.Add("ProjectName", .selectSingleNode("project-name").Text)

			' Load the flag that indicates whether background mode is enabled for the project.
			Call LoadBuildConfiguration.Add("IsBackgroundModeEnabled", .selectSingleNode("is-background-mode-enabled").Text = "True")

			' Load the required reference.
			Set vList = New ClsList
			For Each vChildNode In .selectSingleNode("required-references").childNodes
				Set vItem = CreateObject("Scripting.Dictionary")
				With vChildNode
					Call vItem.Add("Name", .selectSingleNode("name").Text)
					Call vItem.Add("Description", .selectSingleNode("description").Text)
					Call vItem.Add("GUID", .selectSingleNode("guid").Text)
					Call vItem.Add("Major", CLng(.selectSingleNode("major").Text))
					Call vItem.Add("Minor", CLng(.selectSingleNode("minor").Text))
				End With
				Call vList.Add(vItem)
			Next
			Call LoadBuildConfiguration.Add("RequiredReferenceList", vList)

			' Load the required library module file names.
			Set vSet = New ClsSet
			For Each vChildNode In .selectSingleNode("required-library-modules").childNodes
				Call vSet.Add(vChildNode.Text)
			Next
			Call LoadBuildConfiguration.Add("RequiredLibraryModuleSet", vSet)
		End With
	End With
End Function

Function GetFolderDateLastModified( _
	vFolder _
)
	' Declare local variables.
	Dim vSubFolder
	Dim vDateLastModified
	Dim vFile

	' Initialize the result to the smallest possible date value.
	GetFolderDateLastModified = DateSerial(100, 1, 1)

	' Recursively search for the greatest date last modified value among all contained subfolders.
	For Each vSubFolder In vFolder.SubFolders
		vDateLastModified = GetFolderDateLastModified(vSubFolder)
		If vDateLastModified > GetFolderDateLastModified Then
			GetFolderDateLastModified = vDateLastModified
		End If
	Next

	' Recursively search for the greatest date last modified value among all contained files.
	For Each vFile In vFolder.Files
		If vFile.DateLastModified > GetFolderDateLastModified Then
			GetFolderDateLastModified = vFile.DateLastModified
		End If
	Next
End Function

Function IsMainWorkbookOpen( _
	vProjectDirectoryPath _
)
	' The presence of the main workbook temporary file indicates that the main workbook is already open.
	With vFileSystemObject
		IsMainWorkbookOpen = .FileExists(.BuildPath(vProjectDirectoryPath, "~$App.xlsm"))
	End With
End Function

Function GetMainWorkbookFilePath( _
	vProjectDirectoryPath _
)
	GetMainWorkbookFilePath = vFileSystemObject.BuildPath(vProjectDirectoryPath, "App.xlsm")
End Function

Function GetMainWorkbookFilePassword( _
	vBuildConfiguration _
)
	GetMainWorkbookFilePassword = vBuildConfiguration("ProjectName")
End Function

Sub CreateMainWorkbook( _
	vProjectDirectoryPath, _
	vBuildConfiguration _
)
	' Declare local variables.
	Dim vBootstrapFolder
	Dim vLibraryFolder
	Dim vSourceFolder
	Dim vMainWorkbookFilePath
	Dim vReferenceItem
	Dim vModuleFile
	Dim vFileName

	' Load the file system object.
	With vFileSystemObject
		' Load the bootstrap, library and source folder objects.
		Set vBootstrapFolder = .GetFolder(.BuildPath(vProjectDirectoryPath, "Bootstrap"))
		Set vLibraryFolder = .GetFolder(.BuildPath(vProjectDirectoryPath, "Library"))
		Set vSourceFolder = .GetFolder(.BuildPath(vProjectDirectoryPath, "Source"))

		' Determine the main workbook file path.
		vMainWorkbookFilePath = GetMainWorkbookFilePath(vProjectDirectoryPath)

		' Check whether the main workbook file already exists.
		If .FileExists(vMainWorkbookFilePath) Then
			' Load the main workbook file object.
			With .GetFile(vMainWorkbookFilePath)
				' If the main workbook file is newer than any module file or this script, it doesn't need to be rebuilt.
				If ( _
					(GetFolderDateLastModified(vBootstrapFolder) < .DateLastModified) _
					And (GetFolderDateLastModified(vLibraryFolder) < .DateLastModified) _
					And (GetFolderDateLastModified(vSourceFolder) < .DateLastModified) _
					And (vFileSystemObject.GetFile(WScript.ScriptFullName).DateLastModified < .DateLastModified) _
				) Then
					Exit Sub
				End If
			End With

			' Remove the outdated main workbook file.
			Call .DeleteFile(vMainWorkbookFilePath, True)
		End If
	End With

	' Initialize an instance of the excel application.
	With CreateObject("Excel.Application")
		' Set the number of worksheets in new workbooks to one.
		.SheetsInNewWorkbook = 1

		' Create a new workbook.
		With .Workbooks.Add()
			' Load the vbproject of the new workbook.
			With .VBProject
				' Add external references to the VBProject.
				For Each vReferenceItem In vBuildConfiguration("RequiredReferenceList").Items()
					Call .References.AddFromGuid(vReferenceItem("GUID"), vReferenceItem("Major"), vReferenceItem("Minor"))
				Next

				' Import the "ThisUserForm" component from a file.
				Call .VBComponents.Import(vFileSystemObject.BuildPath(vBootstrapFolder.Path, "ThisUserForm.frm"))
				Call .VBComponents("ThisUserForm").CodeModule.DeleteLines(1, 1)

				' Load the contents of the "ThisWorkbook" component from a file.
				With .VBComponents("ThisWorkbook").CodeModule
					Call .DeleteLines(1, 2)
					Call .AddFromFile(vFileSystemObject.BuildPath(vBootstrapFolder.Path, "ThisWorkbook.bas"))
				End With

				' Import the library modules that are listed in the required library modules.
				For Each vFileName In vBuildConfiguration("RequiredLibraryModuleSet").Items()
					Call .VBComponents.Import(vFileSystemObject.BuildPath(vLibraryFolder.Path, vFileName))
				Next

				' Import the source modules.
				For Each vModuleFile In vSourceFolder.Files
					Call .VBComponents.Import(vModuleFile.Path)
				Next
			End With

			' Assign a shortcut key to the initialize macro.
			Call .Application.MacroOptions("ThisWorkbook.Initialize", , , , True, "q")

			' Save and password protect the main workbook file path.
			Call .SaveAs(vMainWorkbookFilePath, xlOpenXMLWorkbookMacroEnabled, GetMainWorkbookFilePassword(vBuildConfiguration))
		End With

		' Close the excel application instance.
		Call .Quit
	End With
End Sub

Sub FormatExportedModuleFile( _
	vFilePath _
)

End Sub

Sub ExportMainWorkbookModules( _
	vProjectDirectoryPath, _
	vBuildConfiguration _
)
	' Declare local variables.
	Dim vBootstrapFolderPath
	Dim vLibraryFolderPath
	Dim vSourceFolderPath
	Dim vModuleFile
	Dim vModuleFilePath
	Dim vVBComponent
	Dim vModuleFileDirectoryPath
	Dim vModuleFileExtension

	' Load the file system object.
	With vFileSystemObject
		' Load the bootstrap, library and source folder objects.
		vBootstrapFolderPath = .BuildPath(vProjectDirectoryPath, "Bootstrap")
		vLibraryFolderPath = .BuildPath(vProjectDirectoryPath, "Library")
		vSourceFolderPath = .BuildPath(vProjectDirectoryPath, "Source")

		' Remove all of the old source module files.
		For Each vModuleFile In .GetFolder(vSourceFolderPath)
			Call vModuleFile.Delete
		Next
	End With

	' Initialize an instance of the excel application.
	With CreateObject("Excel.Application")
		' Open the main workbook file.
		With .Workbooks.Open(GetMainWorkbookFilePath(vProjectDirectoryPath), , True, , GetMainWorkbookFilePassword(vBuildConfiguration))
			' Load the vbproject of the main workbook.
			With .VBProject
				' Write the contents of the "ThisWorkbook" module to a file.
				With .VBComponents("ThisWorkbook").CodeModule
					vModuleFilePath = vFileSystemObject.BuildPath(vBootstrapFolderPath, "ThisWorkbook.bas")
					Call WriteTextFile(vModuleFilePath, .Lines(1, .CountOfLines))
					Call FormatExportedModuleFile(vModuleFilePath)
				End With

				' Export the "ThisUserForm" component to a file.
				vModuleFilePath = vFileSystemObject.BuildPath(vBootstrapFolderPath, "ThisUserForm.frm")
				Call .VBComponents("ThisUserForm").Export(vModuleFilePath)
				Call FormatExportedModuleFile(vModuleFilePath)

				' Export all of the VBProject's components.
				For Each vVBComponent In .VBComponents
					With vVBComponent
						' Determine the module file's directory path.
						If .Name = "ThisUserForm" Then
							vModuleFileDirectoryPath = vBootstrapFolderPath
						ElseIf Left(.Name, 3) = "Lib" Then
							vModuleFileDirectoryPath = vLibraryFolderPath
						Else
							vModuleFileDirectoryPath = vSourceFolderPath
						End If

						' Determine the module file's extension.
						Select Case .Type
							Case vbext_ct_StdModule
								vModuleFileExtension = "bas"
							Case vbext_ct_ClassModule
								vModuleFileExtension = "cls"
							Case vbext_ct_MSForm
								vModuleFileExtension = "frm"
							Case Else
								vModuleFileExtension = vbNullString
						End Select

						' Export the current component to the specfied module if an extension is specified.
						If vModuleFileExtension <> vbNullString Then
							vModuleFilePath = vFileSystemObject.BuildPath(vModuleFileDirectoryPath, .Name & "." & vModuleFileExtension)
							Call .Export(vModuleFilePath)
							Call FormatExportedModuleFile(vModuleFilePath)
						End If
					End With
				Next
			End With
		End With

		' Close the excel application instance.
		Call .Quit
	End With
End Sub

Sub CreateExecuteScript( _
	vProjectDirectoryPath, _
	vBuildConfiguration _
)
	' Declare local variables.
	Dim vTextFileContent

	' Load the file system object.
	With vFileSystemObject
		' Load the contents of the execute script template.
		vTextFileContent = ReadTextFile(.BuildPath(.BuildPath(vProjectDirectoryPath, "Script"), "Execute.vbs"))

		' Set project specific constants.
		vTextFileContent = Replace(vTextFileContent, _
			"Const vIsBackgroundModeEnabled = False", _
			"Const vIsBackgroundModeEnabled = " & CStr(vBuildConfiguration("IsBackgroundModeEnabled")))
		vTextFileContent = Replace(vTextFileContent, _
			"Const vMainWorkbookFilePassword = ""ExcelVBAApplication""", _
			"Const vMainWorkbookFilePassword = """ & GetMainWorkbookFilePassword(vBuildConfiguration) & """")

		' Create the execute script file.
		Call WriteTextFile(.BuildPath(vProjectDirectoryPath, "Execute.vbs"), vTextFileContent)
	End With
End Sub

Sub ShowExcelApplication( _
	vExcelApplication _
)
	' Load the excel application instance.
	With vExcelApplication
		' Make the application window visible and bring it to the forefront
		.Visible = True
		Call vWScriptShell.AppActivate(.Caption)
	End With
End Sub

' Execute content of the file specified in the first argument.
Call ExecuteGlobal(ReadTextFile(WScript.Arguments(0)))