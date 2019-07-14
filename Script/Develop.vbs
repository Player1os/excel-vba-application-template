Option Explicit

' Declare local variables.
Dim vProjectDirectoryPath
Dim vBuildConfiguration

' Retrieve the project's directory path.
vProjectDirectoryPath = GetLocalProjectDirectoryPath()

' If the main workbook is already open, notify the user and exit.
If IsMainWorkbookOpen(vProjectDirectoryPath) Then
	Call MsgBox("The main workbook is already open in a different process and must be closed before proceeding.", vbExclamation)
	Call WScript.Quit
End If

' Load the build configuration from the build configuration xml document.
Set vBuildConfiguration = LoadBuildConfiguration(vFileSystemObject.BuildPath(vProjectDirectoryPath, "Build.xml"))

' Create the main workbook.
Call CreateMainWorkbook(vProjectDirectoryPath, vBuildConfiguration)

' Create the execute script.
Call CreateExecuteScript(vProjectDirectoryPath, vBuildConfiguration)

' Set the environment variable, that indicates that the project is to be run in debug mode.
vWScriptShell.Environment("PROCESS")("APP_IS_DEBUG_MODE_ENABLED") = "TRUE"

' Inialize a backup instance of the Excel application for other workbooks to use.
With CreateObject("Excel.Application")
	' Open the project's main workbook in debug mode.
	With CreateObject("Excel.Application")
		' Display the application window.
		Call ShowExcelApplication(.Application)

		' Open the main workbook file the prepared password.
		Call .Workbooks.Open(GetMainWorkbookFilePath(vProjectDirectoryPath), , , , GetMainWorkbookFilePassword(vBuildConfiguration))

		' ' TODO.
		' Call UnlockVBAProject(vConfigWorkbookExcelApplication)
	End With

	' Wait for the main workbook to be closed.
	Do While IsMainWorkbookOpen(vProjectDirectoryPath)
		Call WScript.Sleep(1000)
	Loop

	' Export the project main workbook's modules.
	Call ExportMainWorkbookModules(vProjectDirectoryPath, vBuildConfiguration)
End With