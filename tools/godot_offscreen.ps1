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
  ... tools/godot_offscreen.ps1 "builds/Strider Home/Strider Home.exe" --quit-after 600   (an exported game, as it is)
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
# An exported game (a .exe instead of a project folder) runs as it is: it carries its own files
$pathArgs = @("--path", $projectPath)
if ($projectPath -like "*.exe") {
	$exe = $projectPath
	$pathArgs = @()
}

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
$cmd = (@($exe, "--audio-driver", "Dummy", "--log-file", $log) + $pathArgs + $GodotArgs |
	ForEach-Object { if ("$_" -match '[\s"]' -or "$_" -eq "") { '"' + ("$_" -replace '"', '\"') + '"' } else { "$_" } }) -join " "

$desk = [HiddenDesktop]::Create($desktopName)
try {
	$proc = [HiddenDesktop]::Start($cmd, $desktopName)
	# Wait for Godot to finish. A script that fails to load leaves Godot running an
	# empty scene forever, so watch the log for that and stop early.
	$deadline = (Get-Date).AddSeconds($TimeoutSec)
	$timedOut = $false
	$scriptBroken = $false
	while ([HiddenDesktop]::WaitForSingleObject($proc, 500) -ne 0) {
		$text = ""
		try {
			$fs = [System.IO.File]::Open($log, "Open", "Read", "ReadWrite")
			$text = (New-Object System.IO.StreamReader($fs)).ReadToEnd()
			$fs.Close()
		} catch {}
		$scriptBroken = $text -match "Parse Error|Failed to load script"
		$timedOut = (Get-Date) -gt $deadline
		if ($scriptBroken -or $timedOut) {
			[void][HiddenDesktop]::TerminateProcess($proc, 1)
			[void][HiddenDesktop]::WaitForSingleObject($proc, 5000)
			break
		}
	}
	$code = [uint32]0
	[void][HiddenDesktop]::GetExitCodeProcess($proc, [ref]$code)
	[void][HiddenDesktop]::CloseHandle($proc)
} finally {
	[void][HiddenDesktop]::CloseDesktop($desk)
}
if (Test-Path $log) { Get-Content $log; Remove-Item $log -ErrorAction SilentlyContinue }
if ($scriptBroken) { Write-Output "godot_offscreen: a script failed to load, stopped Godot"; exit 1 }
if ($timedOut) { Write-Output "godot_offscreen: timed out after $TimeoutSec s, stopped it"; exit 124 }
# A crash's code (like 0xC0000005) is too big for PowerShell's exit: report it and exit 1
if ($code -gt [int]::MaxValue) { Write-Output ("godot_offscreen: Godot crashed (code 0x{0:X8})" -f [uint32]$code); exit 1 }
exit [int]$code
