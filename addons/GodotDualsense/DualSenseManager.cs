using GodotDualsense.Protocol;
using Godot;
using HidSharp;

namespace GodotDualsense;

/// <summary>
/// Autoload singleton exposing DualSense-specific features Godot's built-in Input can't reach:
/// adaptive triggers, lightbar, player LED, touchpad and gyro/accelerometer, and battery level.
/// Standard buttons/sticks/rumble keep working through Godot's normal Input API; this addon only
/// owns the HID output report, so avoid also calling Input.start_joy_vibration for rumble while it's active.
/// </summary>
public partial class DualSenseManager : Node
{
    public static DualSenseManager Instance { get; private set; }

    [Signal]
    public delegate void ControllerConnectedEventHandler();

    [Signal]
    public delegate void ControllerDisconnectedEventHandler();

    public bool IsControllerConnected => _device is { IsConnected: true };
    public DualSenseInputState State { get; private set; }

    private DualSenseDevice _device;
    private double _rescanTimer;
    private const double RescanIntervalSeconds = 2.0;

    public override void _Ready()
    {
        Instance = this;
        ProcessMode = ProcessModeEnum.Always;
        TryConnect();
    }

    public override void _Process(double delta)
    {
        if (_device == null || !_device.IsConnected)
        {
            if (_device != null)
            {
                _device.Dispose();
                _device = null;
                EmitSignal(SignalName.ControllerDisconnected);
            }

            _rescanTimer += delta;
            if (_rescanTimer >= RescanIntervalSeconds)
            {
                _rescanTimer = 0;
                TryConnect();
            }

            return;
        }

        if (_device.TryGetInput(out var state))
        {
            State = state;
        }
    }

    public override void _ExitTree()
    {
        _device?.Dispose();
        _device = null;
        if (Instance == this)
        {
            Instance = null;
        }
    }

    private void TryConnect()
    {
        foreach (var hid in DeviceList.Local.GetHidDevices())
        {
            if (hid.VendorID != DualSenseProtocol.SonyVendorId)
            {
                continue;
            }

            if (hid.ProductID != DualSenseProtocol.DualSenseProductId && hid.ProductID != DualSenseProtocol.DualSenseEdgeProductId)
            {
                continue;
            }

            var device = new DualSenseDevice(hid);
            if (!device.Connect())
            {
                continue;
            }

            _device = device;
            EmitSignal(SignalName.ControllerConnected);
            GD.Print($"DualSense: connected ({(device.IsBluetooth ? "Bluetooth" : "USB")}).");
            return;
        }
    }

    // ---- Lightbar / LED / rumble ----

    public void SetLightbar(Color color)
    {
        if (_device == null) return;
        _device.Output.SetLightbar(color);
        _device.Flush();
    }

    public void SetPlayerLed(DualSensePlayer player, byte brightness = 0x00)
    {
        if (_device == null) return;
        _device.Output.PlayerLedPattern = (byte)player;
        _device.Output.PlayerLedBrightness = brightness;
        _device.Flush();
    }

    public void SetRumble(byte left, byte right)
    {
        if (_device == null) return;
        _device.Output.RumbleLeft = left;
        _device.Output.RumbleRight = right;
        _device.Flush();
    }

    public void SetMicLed(DualSenseMic mic)
    {
        if (_device == null) return;
        _device.Output.MicStatus = (byte)mic;
        _device.Flush();
    }

    public void ResetLights()
    {
        if (_device == null) return;
        _device.Output.LightbarR = 0;
        _device.Output.LightbarG = 0;
        _device.Output.LightbarB = 255;
        _device.Output.PlayerLedPattern = (byte)DualSensePlayer.One;
        _device.Flush();
    }

    // ---- Adaptive triggers ----

    public void SetTriggerOff(DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Off());

    public void SetTriggerResistance(byte startZone, byte strength, DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Resistance(startZone, strength));

    public void SetTriggerGameCube(DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.GameCube());

    public void SetTriggerBow(byte startZone, byte snapBack, DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Bow(startZone, snapBack));

    public void SetTriggerGalloping(byte startPosition, byte endPosition, byte firstFoot, byte secondFoot, byte frequency, DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Galloping(startPosition, endPosition, firstFoot, secondFoot, frequency));

    public void SetTriggerWeapon(byte startZone, byte amplitude, byte behavior, byte trigger, DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Weapon(startZone, amplitude, behavior, trigger));

    public void SetTriggerMachineGun(byte startZone, byte behavior, byte amplitude, byte frequency, DualSenseHand hand = DualSenseHand.Both)
    {
        if (_device == null) return;

        if (hand is DualSenseHand.Left or DualSenseHand.Both)
        {
            _device.Output.LeftTrigger = TriggerEffect.MachineGun(startZone, behavior, amplitude, frequency);
        }

        if (hand is DualSenseHand.Right or DualSenseHand.Both)
        {
            var right = TriggerEffect.MachineGun(startZone, behavior, amplitude, frequency);
            right.Compose[0] = 0xf8; // upstream hardcodes the right trigger's start-zone byte regardless of the parameter
            _device.Output.RightTrigger = right;
        }

        _device.Flush();
    }

    public void SetTriggerMachine(byte startZone, byte behaviorFlag, byte force, byte amplitude, byte period, byte frequency, DualSenseHand hand = DualSenseHand.Both)
    {
        if (_device == null) return;

        if (hand is DualSenseHand.Left or DualSenseHand.Both)
        {
            _device.Output.LeftTrigger = TriggerEffect.Machine(startZone, behaviorFlag, force, amplitude, period, frequency);
        }

        if (hand is DualSenseHand.Right or DualSenseHand.Both)
        {
            var right = TriggerEffect.Machine(startZone, behaviorFlag, force, amplitude, period, frequency);
            right.Compose[1] = (byte)(behaviorFlag > 0 ? 0x02 : 0x00); // upstream's right trigger uses 0x00, not 0x01, for the false case
            _device.Output.RightTrigger = right;
        }

        _device.Flush();
    }

    public void SetTriggerCustom(byte[] tenRawBytes, DualSenseHand hand = DualSenseHand.Both) =>
        ApplyTrigger(hand, TriggerEffect.Custom(tenRawBytes));

    private void ApplyTrigger(DualSenseHand hand, TriggerEffect effect)
    {
        if (_device == null) return;
        if (hand is DualSenseHand.Left or DualSenseHand.Both) _device.Output.LeftTrigger = effect;
        if (hand is DualSenseHand.Right or DualSenseHand.Both) _device.Output.RightTrigger = effect;
        _device.Flush();
    }
}
