using Godot;

namespace GodotDualsense.Protocol;

/// <summary>
/// Mutable output state (rumble, lightbar, LED, adaptive triggers) composed into a raw HID report.
/// Ported from Dualsense-Multiplatform's FOutputContext / FGamepadOutput::OutputDualSense.
/// </summary>
public sealed class DualSenseOutputState
{
    public byte RumbleLeft;
    public byte RumbleRight;

    public byte LightbarR;
    public byte LightbarG;
    public byte LightbarB;

    public byte PlayerLedPattern;
    public byte PlayerLedBrightness;

    public byte VibrationMode = 0xFF;
    public byte FeatureMode = 0b01110111;
    public byte SoftRumbleReduce;
    public byte TriggerSoftnessLevel;

    public byte AudioMode; // 0 = headset, 1 = speaker, 2 = headset+speaker
    public byte HeadsetVolume = 0x7F;
    public byte SpeakerVolume = 100;
    public byte MicVolume = 0x7C;
    public byte MicStatus = 1; // 0 = on, 1 = off; default off so connecting doesn't force the mic LED lit

    public TriggerEffect LeftTrigger = TriggerEffect.Off();
    public TriggerEffect RightTrigger = TriggerEffect.Off();

    public void SetLightbar(Color color)
    {
        LightbarR = (byte)Mathf.RoundToInt(Mathf.Clamp(color.R, 0f, 1f) * 255f);
        LightbarG = (byte)Mathf.RoundToInt(Mathf.Clamp(color.G, 0f, 1f) * 255f);
        LightbarB = (byte)Mathf.RoundToInt(Mathf.Clamp(color.B, 0f, 1f) * 255f);
    }

    /// <summary>
    /// Composes the full output report into the persistent <paramref name="buffer"/> (>= <see cref="DualSenseProtocol.OutputBufferSize"/> bytes).
    /// The buffer must be reused across calls: byte 40 is XOR-toggled each write, matching upstream's required sequence bit.
    /// </summary>
    public void Compose(byte[] buffer, bool isBluetooth)
    {
        var padding = DualSenseProtocol.UsbInputPadding;
        buffer[0] = DualSenseProtocol.UsbOutputReportId;
        if (isBluetooth)
        {
            padding = DualSenseProtocol.BluetoothInputPadding;
            buffer[0] = DualSenseProtocol.BluetoothOutputReportId;
            buffer[1] = 0x02;
        }

        buffer[40] ^= 0x01;

        byte audioModeByte = 0b00000010; // Headset
        if (AudioMode == 1) audioModeByte = 0b00110000; // Speaker
        else if (AudioMode == 2) audioModeByte = 0b00100010; // Headset + Speaker

        var o = padding;
        buffer[o + 0] = VibrationMode;
        buffer[o + 1] = FeatureMode;
        buffer[o + 2] = RumbleRight;
        buffer[o + 3] = RumbleLeft;
        buffer[o + 4] = HeadsetVolume;
        buffer[o + 5] = SpeakerVolume;
        buffer[o + 6] = MicVolume;
        buffer[o + 7] = audioModeByte;
        buffer[o + 8] = (byte)(MicStatus == 0 ? 0x01 : 0x00);
        buffer[o + 9] = 0x00;
        buffer[o + 36] = (byte)((TriggerSoftnessLevel << 4) | (SoftRumbleReduce & 0x0F));
        buffer[o + 42] = PlayerLedBrightness;
        buffer[o + 43] = PlayerLedPattern;
        buffer[o + 44] = LightbarR;
        buffer[o + 45] = LightbarG;
        buffer[o + 46] = LightbarB;

        RightTrigger.WriteTo(buffer, o + 10);
        LeftTrigger.WriteTo(buffer, o + 21);

        if (isBluetooth)
        {
            var crc = Crc32.Compute(buffer, DualSenseProtocol.BluetoothCrcLength);
            buffer[0x4A] = (byte)(crc & 0xFF);
            buffer[0x4B] = (byte)((crc >> 8) & 0xFF);
            buffer[0x4C] = (byte)((crc >> 16) & 0xFF);
            buffer[0x4D] = (byte)((crc >> 24) & 0xFF);
        }
    }
}
