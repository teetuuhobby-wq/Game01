<#
Runs a Godot project for testing without it ever appearing on your screen.

Godot starts on a separate, never-shown Windows desktop. It renders on the real GPU
exactly as normal (screenshots are read straight from the GPU, not from the screen),
but its window can't be seen, can't take your keyboard focus, and can't catch your
mouse. Sound is switched off.

Usage (from the repo root):
  powershell -NoProfile -ExecutionPolicy Bypass -File tools/godot_offscreen.ps1 <project_dir> [-TimeoutSec 300] [godot args...] [-- game args]
Examples:
  ... tools/godot_offscreen.ps1 prototypes/look_test_hd -- --shots
  ... tools/godot_offscreen.ps1 prototypes/look_test_hd --quit-after 600 --print-fps
The game's output is printed when it exits, and the exit code is Godot's (124 = timed out).
For logic-only checks that need no pictures, plain `--headless` is faster.
Set the GODOT environment variable to use a different Godot .exe.
#>
# No param() block on purpose: PowerShell would try to read Godot's --flags as its own.
$ErrorActionPreference = "Stop"
if ($args.Count -lt 1) { throw "usage: godot_offscreen.ps1 <project_dir> [-TimeoutSec N] [godot args...] [-- game args]" }
$Project = $args[0]
$GodotArgs = @($args | Select-Object -Skip 1)
$TimeoutSec = 300
if ($GodotArgs.Count -ge 2 -and $GodotArgs[0] -eq "-TimeoutSec") {
	$TimeoutSec = [int]$GodotArgs[1]
	$GodotArgs = @($GodotArgs | Select-Object -Skip 2)
}

$exe = $env:GODOT
if (-not $exe) {
	$exe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
}
if (-not (Test-Path $exe)) { throw "Godot not found at $exe (set the GODOT environment variable to its .exe)" }
$projectPath = (Resolve-Path $Project).Path.TrimEnd('\')

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class HiddenDesktop {
	[StructLayout(LayoutKind.Sequential)]
	struct STARTUPINFO {
		public int cb; public IntPtr lpReserved, lpDesktop, lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)]
	struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
	[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	static extern IntPtr CreateDesktopW(string name, IntPtr dev, IntPtr mode, int flags, uint access, IntPtr sa);
	[DllImport("user32.dll")] public static extern bool CloseDesktop(IntPtr h);
	[DllImport("user32.dll")] static extern IntPtr GetProcessWindowStation();
	[DllImport("user32.dll", CharSet = CharSet.Unicode)]
	static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder buf, int len, out int needed);
	[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
	static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags,
		IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
	[DllImport("kernel32.dll")] public static extern bool GetExitCodeProcess(IntPtr h, out uint code);
	[DllImport("kernel32.dll")] public static extern bool TerminateProcess(IntPtr h, uint code);
	[DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);

	public static IntPtr Create(string name) {
		var h = CreateDesktopW(name, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000 /* GENERIC_ALL */, IntPtr.Zero);
		if (h == IntPtr.Zero) throw new Exception("CreateDesktop failed: " + Marshal.GetLastWin32Error());
		return h;
	}
	// Starts a process on the named desktop and returns its process handle.
	public static IntPtr Start(string cmdLine, string desktop) {
		var sb = new StringBuilder(256); int n;
		GetUserObjectInformationW(GetProcessWindowStation(), 2 /* UOI_NAME */, sb, 512, out n);
		var si = new STARTUPINFO();
		si.cb = Marshal.SizeOf(typeof(STARTUPINFO));
		si.lpDesktop = Marshal.StringToHGlobalUni(sb.ToString() + "\\" + desktop);
		PROCESS_INFORMATION pi;
		bool ok = CreateProcessW(null, new StringBuilder(cmdLine), IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, null, ref si, out pi);
		Marshal.FreeHGlobal(si.lpDesktop);
		if (!ok) throw new Exception("CreateProcess failed: " + Marshal.GetLastWin32Error());
		CloseHandle(pi.hThread);
		return pi.hProcess;
	}
}
"@

$desktopName = "GodotTest_$PID"
$log = [System.IO.Path]::GetTempFileName()
# Quote each argument for the Windows command line.
$cmd = (@($exe, "--audio-driver", "Dummy", "--log-file", $log, "--path", $projectPath) + $GodotArgs |
	ForEach-Object { if ("$_" -match '[\s"]' -or "$_" -eq "") { '"' + ("$_" -replace '"', '\"') + '"' } else { "$_" } }) -join " "

$desk = [HiddenDesktop]::Create($desktopName)
try {
	$proc = [HiddenDesktop]::Start($cmd, $desktopName)
	$timedOut = [HiddenDesktop]::WaitForSingleObject($proc, [uint32]($TimeoutSec * 1000)) -ne 0
	if ($timedOut) { [void][HiddenDesktop]::TerminateProcess($proc, 124); [void][HiddenDesktop]::WaitForSingleObject($proc, 5000) }
	$code = [uint32]0
	[void][HiddenDesktop]::GetExitCodeProcess($proc, [ref]$code)
	[void][HiddenDesktop]::CloseHandle($proc)
} finally {
	[void][HiddenDesktop]::CloseDesktop($desk)
}
if (Test-Path $log) { Get-Content $log; Remove-Item $log -ErrorAction SilentlyContinue }
if ($timedOut) { Write-Output "godot_offscreen: timed out after $TimeoutSec s, stopped it"; exit 124 }
exit [int]$code
