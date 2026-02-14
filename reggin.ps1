# ================================
# ULTRA Minecraft Loader 1.21+
# Fully In-Memory / DLL-less
# ================================

$ErrorActionPreference = "SilentlyContinue"

# --- Randomized symbol generator ---
function New-RandName {
    -join ((65..90)+(97..122) | Get-Random -Count 12 | % {[char]$_})
}

# --- XOR Runtime Decrypt ---
function Decode-XOR {
    param($data,$key)
    $out = ""
    for ($i=0;$i -lt $data.Length;$i++) {
        $out += [char]([byte][char]$data[$i] -bxor $key)
    }
    return $out
}

# --- Encrypted strings ---
$encJava = "0?4?5-?"  # xor'd "javaw.exe"
$javaStr = Decode-XOR $encJava 42

# --- Find Minecraft ---
$proc = Get-Process | Where-Object { $_.Name -like "*javaw*" } | Select -First 1
if (!$proc) { exit }

# --- Dynamic C# Build ---
$randClass = New-RandName
$randMethod = New-RandName

$code = @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Text;
using System.Windows.Forms;
using System.Threading;
using System.Drawing;
using System.Drawing.Drawing2D;

public class $randClass {

    [DllImport("ntdll.dll")]
    static extern int NtOpenProcess(ref IntPtr ProcessHandle, uint DesiredAccess, ref OBJECT_ATTRIBUTES ObjectAttributes, ref CLIENT_ID ClientId);

    [DllImport("ntdll.dll")]
    static extern int NtReadVirtualMemory(IntPtr ProcessHandle, IntPtr BaseAddress, byte[] Buffer, int NumberOfBytesToRead, ref int NumberOfBytesRead);

    [StructLayout(LayoutKind.Sequential)]
    public struct CLIENT_ID {
        public IntPtr UniqueProcess;
        public IntPtr UniqueThread;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct OBJECT_ATTRIBUTES {
        public int Length;
        public IntPtr RootDirectory;
        public IntPtr ObjectName;
        public uint Attributes;
        public IntPtr SecurityDescriptor;
        public IntPtr SecurityQualityOfService;
    }

    [DllImport("ntdll.dll")]
    static extern uint NtUserSendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT {
        public int type;
        public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    const uint PROCESS_VM_READ = 0x0010;
    const uint PROCESS_QUERY_INFORMATION = 0x0400;

    public static void $randMethod(int pid) {

        IntPtr hProc = IntPtr.Zero;

        CLIENT_ID cid = new CLIENT_ID();
        cid.UniqueProcess = (IntPtr)pid;

        OBJECT_ATTRIBUTES oa = new OBJECT_ATTRIBUTES();
        oa.Length = Marshal.SizeOf(typeof(OBJECT_ATTRIBUTES));

        NtOpenProcess(ref hProc, PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, ref oa, ref cid);

        byte[] buffer = new byte[1024];
        int bytesRead = 0;

        NtReadVirtualMemory(hProc, (IntPtr)0x00000000, buffer, buffer.Length, ref bytesRead);

        Thread overlay = new Thread(() => RunOverlay());
        overlay.Start();
    }

    static void RunOverlay() {
        Form f = new Form();
        f.FormBorderStyle = FormBorderStyle.None;
        f.TopMost = true;
        f.Width = 400;
        f.Height = 300;
        f.StartPosition = FormStartPosition.CenterScreen;
        f.BackColor = Color.Black;
        f.Opacity = 0.9;

        Button trigger = new Button();
        trigger.Text = "TriggerBot";
        trigger.Location = new Point(50,50);
        trigger.Click += (s,e)=> TriggerBot();

        Button shield = new Button();
        shield.Text = "AutoShieldBreak";
        shield.Location = new Point(50,100);
        shield.Click += (s,e)=> ShieldBreak();

        Button selfd = new Button();
        selfd.Text = "Self Destruct";
        selfd.Location = new Point(50,150);
        selfd.Click += (s,e)=> SelfDestruct();

        f.Controls.Add(trigger);
        f.Controls.Add(shield);
        f.Controls.Add(selfd);

        Application.Run(f);
    }

    static void TriggerBot() {
        INPUT[] inp = new INPUT[1];
        inp[0].type = 0;
        inp[0].mi.dwFlags = 0x0002; // left down
        NtUserSendInput(1, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    static void ShieldBreak() {
        INPUT[] inp = new INPUT[2];

        inp[0].type = 0;
        inp[0].mi.dwFlags = 0x0002;
        inp[1].type = 0;
        inp[1].mi.dwFlags = 0x0004;

        NtUserSendInput(2, inp, Marshal.SizeOf(typeof(INPUT)));
    }

    static void SelfDestruct() {
        string path = Process.GetCurrentProcess().MainModule.FileName;
        File.Delete(path);
        Environment.Exit(0);
    }
}
"@

Add-Type -TypeDefinition $code -Language CSharp

[Reflection.Assembly]::GetExecutingAssembly().ManifestModule.ModuleHandle

$method = ($randClass)::GetMethod($randMethod)
$method.Invoke($null,@($proc.Id))

# --- PE Header Wipe ---
$module = [System.Runtime.InteropServices.Marshal]::GetHINSTANCE([System.Reflection.Assembly]::GetExecutingAssembly().GetModules()[0])
[System.Runtime.InteropServices.Marshal]::Copy((0..1024 | % {0}),0,$module,1024)

# --- Anti Forensics ---
Clear-History
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
