using CascLib.NET;
using System.Runtime.InteropServices;
using System.Text.Json;

const uint CascLocaleAll = 0xFFFFFFFF;

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
    foreach (string assetPath in assetPaths)
    {
        string normalized = NormalizePath(assetPath);
        bool opened = TryOpen(storage.Handle, normalized, out nint fileHandle);
        ulong bytesCopied = 0;
        if (opened)
        {
            using var stream = new CascFileStream(fileHandle, normalized);
            bytesCopied = Drain(stream);
        }

        results.Add(new
        {
            assetPath = normalized,
            opened,
            fileHandle = fileHandle.ToInt64(),
            bytesCopied,
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
    var manifest = new List<object>();

    foreach (string rawAssetPath in assetPaths)
    {
        string assetPath = NormalizePath(rawAssetPath);
        string outputPath = Path.Combine(outputDir, SafeOutputName(assetPath));
        bool opened = TryOpen(storage.Handle, assetPath, out nint fileHandle);

        if (!opened)
        {
            missing++;
            manifest.Add(new
            {
                assetPath,
                opened = false,
                outputPath = "",
                bytesWritten = 0UL,
            });
            continue;
        }

        ulong bytesWritten;
        using (var stream = new CascFileStream(fileHandle, assetPath))
        using (var output = File.Create(outputPath))
        {
            bytesWritten = CopyStream(stream, output);
        }

        if (bytesWritten == 0)
        {
            File.Delete(outputPath);
            missing++;
            manifest.Add(new
            {
                assetPath,
                opened = true,
                outputPath = "",
                bytesWritten,
            });
            continue;
        }

        extracted++;
        manifest.Add(new
        {
            assetPath,
            opened = true,
            outputPath,
            bytesWritten,
        });
    }

    Console.WriteLine(JsonSerializer.Serialize(new
    {
        storagePath,
        outputDir,
        extracted,
        missing,
        entries = manifest,
    }, new JsonSerializerOptions
    {
        WriteIndented = true,
    }));

    return 0;
}

static bool TryOpen(nint storageHandle, string assetPath, out nint fileHandle)
{
    fileHandle = IntPtr.Zero;
    return NativeCasc.CascOpenFile(storageHandle, assetPath, CascLocaleAll, 0, ref fileHandle)
        && fileHandle != IntPtr.Zero;
}

static ulong CopyStream(Stream input, Stream output)
{
    byte[] buffer = new byte[1024 * 64];
    ulong total = 0;

    while (true)
    {
        int read = input.Read(buffer, 0, buffer.Length);
        if (read <= 0)
        {
            break;
        }

        output.Write(buffer, 0, read);
        total += (ulong)read;
    }

    return total;
}

static ulong Drain(Stream input)
{
    byte[] buffer = new byte[1024 * 64];
    ulong total = 0;

    while (true)
    {
        int read = input.Read(buffer, 0, buffer.Length);
        if (read <= 0)
        {
            break;
        }

        total += (ulong)read;
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

sealed class CascStorageHandle : IDisposable
{
    public CascStorageHandle(string storagePath)
    {
        if (!NativeCasc.CascOpenStorage(storagePath, 0, ref _handle) || _handle == IntPtr.Zero)
        {
            throw new InvalidOperationException($"Failed to open CASC storage: {storagePath}");
        }
    }

    private nint _handle;

    public nint Handle => _handle;

    public void Dispose()
    {
        if (_handle != IntPtr.Zero)
        {
            NativeCasc.CascCloseStorage(_handle);
            _handle = IntPtr.Zero;
        }
    }
}

static partial class NativeCasc
{
    [LibraryImport("CascLib.dll", EntryPoint = "CascOpenStorage", SetLastError = true, StringMarshalling = StringMarshalling.Utf8)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CascOpenStorage(string storagePath, uint localeMask, ref nint storageHandle);

    [LibraryImport("CascLib.dll", EntryPoint = "CascCloseStorage", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CascCloseStorage(nint storageHandle);

    [LibraryImport("CascLib.dll", EntryPoint = "CascOpenFile", SetLastError = true, StringMarshalling = StringMarshalling.Utf8)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static partial bool CascOpenFile(nint storageHandle, string fileName, uint localeFlags, uint openFlags, ref nint fileHandle);
}
