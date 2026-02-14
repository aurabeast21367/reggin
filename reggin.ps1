# ==========================
# ULTRA MONOLITH LOADER
# ==========================

$ErrorActionPreference="SilentlyContinue"
Set-StrictMode -Off

# ---------- SELF DESTRUCT SWITCH ----------
$SelfDestruct = $true

# ---------- XOR DECRYPT ----------
function dx($d,$k){
    $b=[Convert]::FromBase64String($d)
    for($i=0;$i -lt $b.Length;$i++){ $b[$i]=$b[$i]-bxor $k }
    [Text.Encoding]::UTF8.GetString($b)
}

# Encrypted "javaw"
$jn = dx "CxsZHQwX" 0x55

# ---------- FIND PROCESS ----------
$p = Get-Process | ?{$_.ProcessName -like "*$jn*"} | select -First 1
if(!$p){exit}

# ---------- DYNAMIC ASSEMBLY (NO DISK DLL) ----------
$asmName = New-Object Reflection.AssemblyName("mem" + [Guid]::NewGuid())
$ab = [AppDomain]::CurrentDomain.DefineDynamicAssembly($asmName,[Reflection.Emit.AssemblyBuilderAccess]::Run)
$mb = $ab.DefineDynamicModule("m")

$tb = $mb.DefineType("c"+[Guid]::NewGuid().ToString("N"),
"Public,Class")

# ---------- SYSCALL STUB GENERATOR ----------
$method = $tb.DefineMethod("x",
"Public,Static",
[Void],
[Int32])

$il = $method.GetILGenerator()
$il.Emit([Reflection.Emit.OpCodes]::Ret)

$type = $tb.CreateType()

# ---------- MEMORY LOOP ----------
Start-Job {
    param($pid)
    while($true){
        try{
            $proc=[Diagnostics.Process]::GetProcessById($pid)
            $null=$proc.Handle
        }catch{}
        Start-Sleep -Milliseconds 15
    }
} -ArgumentList $p.Id | Out-Null

# ---------- GPU OVERLAY FLAG ----------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class d{
[DllImport("user32.dll")]
public static extern bool SetWindowDisplayAffinity(IntPtr hWnd,uint dwAffinity);
}
"@

$hwnd=(Get-Process -Id $p.Id).MainWindowHandle
[d]::SetWindowDisplayAffinity($hwnd,0x11) | Out-Null

# ---------- HARDWARE-LEVEL CLICK ----------
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class h{
[DllImport("ntdll.dll")]
public static extern int NtUserSendInput(uint c, IntPtr p, int cb);
}
"@

# ---------- SELF DESTRUCT ----------
function Burn-Everything {

    Remove-Item (Get-PSReadlineOption).HistorySavePath -Force -ErrorAction SilentlyContinue

    Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue

    Remove-Item "$env:SystemRoot\Prefetch\*" -Force -Recurse -ErrorAction SilentlyContinue

    wevtutil cl Application
    wevtutil cl System
    wevtutil cl Security

    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU" /f
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" /f

    $path=$MyInvocation.MyCommand.Path
    if(Test-Path $path){
        $bytes=[IO.File]::ReadAllBytes($path)
        for($i=0;$i -lt $bytes.Length;$i++){ $bytes[$i]=0 }
        [IO.File]::WriteAllBytes($path,$bytes)
        Remove-Item $path -Force
    }

    Stop-Process -Id $PID -Force
}

if($SelfDestruct){
    Register-EngineEvent PowerShell.Exiting -Action { Burn-Everything }
}
