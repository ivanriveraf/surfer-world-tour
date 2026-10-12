using System;
using System.Threading;
using GodotDualsense.Protocol;
using Godot;
using HidSharp;

namespace GodotDualsense;

/// <summary>
/// Owns one physical DualSense controller: raw HID transport, a background read loop,
/// and output report composition/writing.
/// </summary>
public sealed class DualSenseDevice : IDisposable
{
    public bool IsBluetooth { get; private set; }
    public bool IsConnected { get; private set; }
    public DualSenseOutputState Output { get; } = new();

    private readonly HidDevice _hidDevice;
    private HidStream _stream;
    private Thread _readThread;
    private volatile bool _running;

    private readonly object _inputLock = new();
    private DualSenseInputState _latestInput;
    private bool _hasInput;

    private readonly byte[] _outputScratch = new byte[DualSenseProtocol.OutputBufferSize];
    private readonly object _outputLock = new();

    public DualSenseDevice(HidDevice hidDevice)
    {
        _hidDevice = hidDevice;
    }

    public bool Connect()
    {
        if (!_hidDevice.TryOpen(out _stream))
        {
            return false;
        }

        // Probe one report to tell USB (report 0x01) from Bluetooth (report 0x31); they use different padding/CRC framing.
        var probe = new byte[_hidDevice.GetMaxInputReportLength()];
        _stream.ReadTimeout = 500;
        var read = 0;
        try
        {
            read = _stream.Read(probe, 0, probe.Length);
        }
        catch (Exception)
        {
            // Timed out or the device went away before it produced a report; treat as USB and let the read loop retry.
        }

        IsBluetooth = read > 0 && probe[0] == DualSenseProtocol.BluetoothInputReportId;
        _stream.ReadTimeout = Timeout.Infinite;

        IsConnected = true;
        _running = true;
        _readThread = new Thread(ReadLoop) { IsBackground = true, Name = "DualSenseRead" };
        _readThread.Start();

        Flush();
        return true;
    }

    private void ReadLoop()
    {
        var buffer = new byte[_hidDevice.GetMaxInputReportLength()];
        var padding = IsBluetooth ? DualSenseProtocol.BluetoothInputPadding : DualSenseProtocol.UsbInputPadding;

        while (_running)
        {
            int read;
            try
            {
                read = _stream.Read(buffer, 0, buffer.Length);
            }
            catch (Exception)
            {
                break;
            }

            if (read <= padding)
            {
                continue;
            }

            var parsed = DualSenseInputState.Parse(new ReadOnlySpan<byte>(buffer, padding, read - padding));
            lock (_inputLock)
            {
                _latestInput = parsed;
                _hasInput = true;
            }
        }

        IsConnected = false;
    }

    public bool TryGetInput(out DualSenseInputState state)
    {
        lock (_inputLock)
        {
            state = _latestInput;
            return _hasInput;
        }
    }

    /// <summary>Composes the current <see cref="Output"/> state and writes it as a single HID output report.</summary>
    public void Flush()
    {
        if (_stream == null)
        {
            return;
        }

        lock (_outputLock)
        {
            Output.Compose(_outputScratch, IsBluetooth);

            var wireLength = _hidDevice.GetMaxOutputReportLength();
            if (wireLength <= 0 || wireLength > _outputScratch.Length)
            {
                wireLength = _outputScratch.Length;
            }

            try
            {
                _stream.Write(_outputScratch, 0, wireLength);
            }
            catch (Exception e)
            {
                GD.PushWarning($"DualSense: output write failed: {e.Message}");
            }
        }
    }

    public void Dispose()
    {
        _running = false;
        try
        {
            _stream?.Close();
        }
        catch (Exception)
        {
            // Best-effort close; the device may already be gone.
        }

        _readThread?.Join(200);
        _stream?.Dispose();
    }
}
