/*----------------------------------------------------------
OpenKey - The Cross platform Open source Vietnamese Keyboard application.

Copyright (C) 2019 Mai Vu Tuyen
Contact: maivutuyen.91@gmail.com
Github: https://github.com/tuyenvm/OpenKey
Fanpage: https://www.facebook.com/OpenKeyVN

This file is belong to the OpenKey project, Win32 version
which is released under GPL license.
You can fork, modify, improve this program. If you
redistribute your new version, it MUST be open source.
-----------------------------------------------------------*/

#include "framework.h"
#include "OpenKeyUpdate.h"
#include <Urlmon.h>
#include <fstream>
#include <sstream>
#include <string>
#pragma comment(lib, "Urlmon.lib")

using namespace std;

INT_PTR CALLBACK MainDialogProcess(HWND, UINT, WPARAM, LPARAM);
void StartUpdate();
HWND hDlg;
int APIENTRY wWinMain(_In_ HINSTANCE hInstance,
                     _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR    lpCmdLine,
                     _In_ int       nCmdShow)
{
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

	hDlg = CreateDialogParam(hInstance, MAKEINTRESOURCE(IDD_DIALOG_UPDATER), 0, MainDialogProcess, 0);
	ShowWindow(hDlg, SW_SHOWNORMAL);
 
	MSG msg;
	// Main message loop:
	while (GetMessage(&msg, nullptr, 0, 0)) {
		if (!IsDialogMessage(hDlg, &msg)) {
			TranslateMessage(&msg);
			DispatchMessage(&msg);
		}
	}
	return 0;
}

// Message handler for about box.
INT_PTR CALLBACK MainDialogProcess(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
    UNREFERENCED_PARAMETER(lParam);
	switch (message) {
	case WM_INITDIALOG:{
		HICON hIcon = LoadIcon(GetModuleHandle(NULL), MAKEINTRESOURCE(IDI_OPENKEYUPDATE));
		if (hIcon) {
			SendMessage(hDlg, WM_SETICON, ICON_BIG, (LPARAM)hIcon);
		}
		StartUpdate();
		return (INT_PTR)TRUE;
	}
    case WM_COMMAND:
        if (LOWORD(wParam) == IDOK || LOWORD(wParam) == IDCANCEL)
        {
            EndDialog(hDlg, LOWORD(wParam));
            return (INT_PTR)TRUE;
        }
        break;
    }
    return (INT_PTR)FALSE;
}

DWORD WINAPI UpdateThreadFunction(LPVOID lpParam) {
	//work in the folder of the updater (next to OpenKey64.exe), not the current directory
	WCHAR path[MAX_PATH];
	WCHAR currentDir[MAX_PATH];
	GetModuleFileName(NULL, currentDir, MAX_PATH);
	WCHAR* slash = wcsrchr(currentDir, L'\\');
	if (slash) *slash = 0;
	SetCurrentDirectory(currentDir);
	_snwprintf_s(path, MAX_PATH, _TRUNCATE, TEXT("%s\\_OpenKey.tempf"), currentDir);
	HRESULT res = URLDownloadToFile(NULL, L"https://raw.githubusercontent.com/tuyenvm/OpenKey/master/version.json", path, 0, NULL);

	wstring data;
	if (res == S_OK) {
		std::wifstream t(path);
		std::wstringstream buffer;
		buffer << t.rdbuf();
		t.close();
		DeleteFile(path);
		data = buffer.str();
	} else {
		MessageBox(hDlg, _T("Có lỗi trong quá trình cập nhật, vui lòng thử lại sau!"), _T("OpenKey Update"), MB_OK);
		ExitProcess(0);
		return 0;
	}

	//simple parse, every step checked (a captive portal page is not version.json)
	size_t p = data.find(L"latestWinVersion");
	if (p != wstring::npos) p = data.find(L"\"versionName\":", p);
	if (p != wstring::npos) p = data.find(L'"', p + 14);
	size_t e = (p != wstring::npos) ? data.find(L'"', p + 1) : wstring::npos;
	bool ok = (e != wstring::npos && e - p - 1 <= 32);
	wstring versionName = ok ? data.substr(p + 1, e - p - 1) : L"";

	//download zip file
	WCHAR updateUrl[512];
	_snwprintf_s(updateUrl, _countof(updateUrl), _TRUNCATE, TEXT("https://github.com/tuyenvm/OpenKey/releases/download/%s/OpenKey%s-Windows.zip"),
		versionName.c_str(),
		versionName.c_str());
	ok = ok && URLDownloadToFile(NULL, updateUrl, L"_OpenKeyUpdate.zip", 0, NULL) == S_OK;

	if (ok) { //extract and wait for it to finish
		WCHAR cmd[] = L"powershell.exe -NoP -NonI -Command \"Expand-Archive -Force '.\\_OpenKeyUpdate.zip' '.\\_OpenKeyUpdate'\"";
		STARTUPINFO si = { sizeof(si) };
		PROCESS_INFORMATION pi = {};
		ok = CreateProcess(NULL, cmd, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &pi) != 0;
		if (ok) {
			WaitForSingleObject(pi.hProcess, INFINITE);
			CloseHandle(pi.hThread);
			CloseHandle(pi.hProcess);
		}
	}
	ok = ok && GetFileAttributes(L"_OpenKeyUpdate\\OpenKey64.exe") != INVALID_FILE_ATTRIBUTES;
	if (ok) { //only replace the installed exe once the new one is there; renaming works while it runs
		DeleteFile(L"OpenKey64.exe.old");
		MoveFileEx(L"OpenKey64.exe", L"OpenKey64.exe.old", MOVEFILE_REPLACE_EXISTING);
		ok = MoveFileEx(L"_OpenKeyUpdate\\OpenKey64.exe", L"OpenKey64.exe", MOVEFILE_REPLACE_EXISTING) != 0;
		if (!ok) //put the old version back
			MoveFileEx(L"OpenKey64.exe.old", L"OpenKey64.exe", MOVEFILE_REPLACE_EXISTING);
		DeleteFile(L"OpenKey64.exe.old");
	}
	DeleteFile(L"_OpenKeyUpdate.zip");
	DeleteFile(L"_OpenKeyUpdate\\OpenKeyUpdate.exe");
	DeleteFile(L"_OpenKeyUpdate\\OpenKey64.exe");
	DeleteFile(L"_OpenKeyUpdate\\OpenKey32.exe");
	RemoveDirectory(L"_OpenKeyUpdate");
	MessageBox(hDlg, ok ? _T("Bạn đã cập nhật OpenKey bản mới nhất thành công!")
	                    : _T("Có lỗi trong quá trình cập nhật, vui lòng thử lại sau!"), _T("OpenKey Update"), MB_OK);
	ExitProcess(0);
	return 0;
}

void StartUpdate() {
	DWORD hThread;
	HANDLE t = CreateThread(
							NULL,                   // default security attributes
							0,                      // use default stack size  
							UpdateThreadFunction,       // thread function name
							0,          // argument to thread function 
							0,                      // use default creation flags 
							&hThread);   // returns the thread identifier 
}