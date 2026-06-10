using CascLib.NET;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text.Json;

BootstrapNativeDllPath();

if (args.Length < 3)
{
    Console.Error.WriteLine("""
        Usage:
          MutatorCascProbe extract <storage-path> <output-dir> <asset-path> [asset-path...]
          MutatorCascProbe probe <storage-path> <asset-path> [asset-path...]
        """);
    return 2;
}

string command = args[0].ToLowerInvariant();
string storagePath = args[1];

if (!Directory.Exists(storagePath))
{
    Console.Error.WriteLine($"Storage path does not exist: {storagePath}");
    return 1;
}

return command switch
{
    "extract" => Extract(storagePath, args[2], args.Skip(3).ToArray()),
    "probe" => Probe(storagePath, args.Skip(2).ToArray()),
    _ => 2,
};

static int Probe(string storagePath, string[] assetPaths)
{
    if (assetPaths.Length == 0)
    {
        Console.Error.WriteLine("No asset paths supplied.");
        return 2;
    }

    using var storage = new CascStorageHandle(storagePath);
    var results = new List<object>();

    foreach (string rawAssetPath in assetPaths)
    {
        string assetPath = NormalizePath(rawAssetPath);
        bool opened = storage.TryOpenFile(assetPath, out nint fileHandle);
        ulong size = 0;
        ulong bytesRead = 0;
        string error = "";

        if (opened)
        {
            try
            {
                size = NativeCasc.GetFileSize(fileHandle);
                bytesRead = DrainFile(fileHandle);
            }
            catch (Exception ex)
            {
                error = ex.Message;
            }
            finally
            {
                NativeCasc.CascCloseFile(fileHandle);
            }
        }
        else
        {
            error = new Win32Exception(Marshal.GetLastPInvokeError()).Message;
        }

        results.Add(new
        {
            assetPath,
            opened,
            fileHandle = fileHandle.ToInt64(),
            size,
            bytesRead,
            error,
        });
    }

    Console.WriteLine(JsonSerializer.Serialize(results, new JsonSerializerOptions
    {
        WriteIndented = true,
    }));
    return 0;
}

static int Extract(string storagePath, string outputDir, string[] assetPaths)
{
    if (assetPaths.Length == 0)
    {
        Console.Error.WriteLine("No asset paths supplied.");
        return 2;
    }

    Directory.CreateDirectory(outputDir);

    using var storage = new CascStorageHandle(storagePath);
    int extracted = 0;
    int missing = 0;
    var entries = new List<object>();

    foreach (string rawAssetPath in assetPaths)
    {
        string assetPath = NormalizePath(rawAssetPath);
        string outputPath = Path.Combine(outputDir, SafeOutputName(assetPath));

        if (!storage.TryOpenFile(assetPath, out nint fileHandle))
        {
            missing++;
            entries.Add(new
            {
                assetPath,
                opened = false,
                outputPath = "",
                bytesWritten = 0UL,
                error = new Win32Exception(Marshal.GetLastPInvokeError()).Message,
            });
            continue;
        }

        ulong bytesWritten = 0;
        string error = "";
        try
        {
            using var output = File.Create(outputPath);
            bytesWritten = CopyFile(fileHandle, output);
        }
        catch (Exception ex)
        {
            error = ex.Message;
        }
        finally
        {
            NativeCasc.CascCloseFile(fileHandle);
        }

        if (bytesWritten == 0)
        {
            if (File.Exists(outputPath))
            {
                File.Delete(outputPath);
            }

            missing++;
            entries.Add(new
            {
                assetPath,
                opened = true,
                outputPath = "",
                bytesWritten,
                error = error.Length == 0 ? "zero-byte-read" : error,
            });
            continue;
        }

        extracted++;
        entries.Add(new
        {
            assetPath,
            opened = true,
            outputPath,
            bytesWritten,
            error,
        });
    }

    Console.WriteLine(JsonSerializer.Serialize(new
    {
        storagePath,
        outputDir,
        extracted,
        missing,
        entries,
    }, new JsonSerializerOptions
    {
        WriteIndented = true,
    }));

    return 0;
}

static ulong CopyFile(nint fileHandle, Stream output)
{
    byte[] buffer = new byte[1024 * 64];
    ulong total = 0;

    while (true)
    {
        uint read = NativeCasc.Read(fileHandle, buffer, (uint)buffer.Length);
        if (read == 0)
        {
            break;
        }

        output.Write(buffer, 0, (int)read);
        total += read;
    }

    return total;
}

static ulong DrainFile(nint fileHandle)
{
    byte[] buffer = new byte[1024 * 64];
    ulong total = 0;

    while (true)
    {
        uint read = NativeCasc.Read(fileHandle, buffer, (uint)buffer.Length);
        if (read == 0)
        {
            break;
        }

        total += read;
    }

    return total;
}

static string NormalizePath(string assetPath)
{
    return assetPath.Replace('/', '\\').Trim();
}

static string SafeOutputName(string assetPath)
{
    return assetPath.Replace('\\', '_').Replace('/', '_').Replace(':', '_');
}

static void BootstrapNativeDllPath()
{
    string nativeDir = Path.Combine(AppContext.BaseDirectory, "runtimes", "win-x64", "native");
    NativeLoader.SetDllDirectory(nativeDir);
    string currentPath = Environment.GetEnvironmentVariable("PATH") ?? "";
    if (!currentPath.Contains(nativeDir, StringComparison.OrdinalIgnoreCase))
    {
        Environment.SetEnvironmentVariable("PATH", nativeDir + ";" + currentPath);
    }
}

sealed class CascStorageHandle : IDisposable
{
    private nint _handle;
    public int OpenError { get; }

    public CascStorageHandle(string storagePath)
    {
        if (!global::CascLib.NET.CascLib.CascOpenStorage(storagePath, 0, out _handle) || _handle == IntPtr.Zero)
        {
            OpenError = Marshal.GetLastPInvokeError();
            throw new InvalidOperationException($"CascOpenStorage failed: {storagePath}; win32={OpenError}; handle={_handle.ToInt64()}");
        }
    }

    public bool TryOpenFile(string assetPath, out nint fileHandle)
    {
        bool opened = global::CascLib.NET.CascLib.CascOpenFile(_handle, assetPath, 0xFFFFFFFF, 0, out fileHandle);
        return opened && fileHandle != IntPtr.Zero;
    }

    public void Dispose()
    {
        if (_handle != IntPtr.Zero)
        {
            global::CascLib.NET.CascLib.CascCloseStorage(_handle);
        }

        _handle = IntPtr.Zero;
    }
}

static class NativeLoader
{
    [DllImport("kernel32.dll", EntryPoint = "SetDllDirectoryW", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetDllDirectory(string lpPathName);
}

static class NativeCasc
{
    public static ulong GetFileSize(nint fileHandle)
    {
        if (!global::CascLib.NET.CascLib.CascGetFileSize64(fileHandle, out ulong size))
        {
            throw new InvalidOperationException($"CascGetFileSize64 failed. Win32={Marshal.GetLastPInvokeError()}");
        }

        return size;
    }

    public static uint Read(nint fileHandle, byte[] buffer, uint bytesToRead)
    {
        if (!global::CascLib.NET.CascLib.CascReadFile(fileHandle, buffer, bytesToRead, out uint read))
        {
            throw new InvalidOperationException($"CascReadFile failed. Win32={Marshal.GetLastPInvokeError()}");
        }

        return read;
    }

    public static bool CascCloseFile(nint fileHandle)
    {
        return global::CascLib.NET.CascLib.CascCloseFile(fileHandle);
    }
}
