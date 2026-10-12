using System;

namespace GodotDualsense.Protocol;

/// <summary>
/// One adaptive-trigger effect (10 raw parameter bytes + mode). Builders ported from
/// Dualsense-Multiplatform's FDualSenseTriggerComposer / FGamepadOutput::SetTriggerEffects.
/// </summary>
public struct TriggerEffect
{
    public byte Mode;
    public byte[] Compose;

    private TriggerEffect(byte mode, params byte[] compose)
    {
        Mode = mode;
        Compose = new byte[10];
        Array.Copy(compose, Compose, Math.Min(compose.Length, 10));
    }

    public static TriggerEffect Off() => new(0x00);

    public static TriggerEffect Resistance(byte startZone, byte strength) =>
        new(0x01, startZone, strength);

    public static TriggerEffect GameCube() =>
        new(0x02, 0x90, 0x0a, 0xff);

    public static TriggerEffect Bow(byte startZone, byte snapBack) =>
        new(0x22, startZone, 0x01, snapBack);

    public static TriggerEffect Galloping(byte startPosition, byte endPosition, byte firstFoot, byte secondFoot, byte frequency)
    {
        var firstFootNib = (byte)Math.Clamp((int)MathF.Round(firstFoot / 8f * 15f), 1, 15);
        var secondFootNib = (byte)Math.Clamp((int)MathF.Round(secondFoot / 8f * 15f), 1, 15);
        var positionMask = (ushort)((1 << startPosition) | (1 << endPosition));
        return new TriggerEffect(0x23,
            (byte)(positionMask & 0xFF),
            (byte)((positionMask >> 8) & 0xFF),
            (byte)(((firstFootNib & 0x0F) << 4) | (secondFootNib & 0x0F)),
            frequency);
    }

    public static TriggerEffect Weapon(byte startZone, byte amplitude, byte behavior, byte trigger) =>
        new(0x25, (byte)((startZone << 4) | (amplitude & 0x0F)), behavior, (byte)(trigger & 0x0F));

    public static TriggerEffect MachineGun(byte startZone, byte behavior, byte amplitude, byte frequency)
    {
        var effect = new TriggerEffect(0x26);
        effect.Compose[0] = startZone;
        effect.Compose[1] = (byte)(behavior > 0 ? 0x03 : 0x00);
        effect.Compose[4] = (byte)(amplitude == 1 ? 0x8F : 0x8a);
        effect.Compose[5] = (byte)(amplitude == 2 ? 0x3F : 0x1F);
        effect.Compose[9] = frequency;
        return effect;
    }

    public static TriggerEffect Machine(byte startZone, byte behaviorFlag, byte force, byte amplitude, byte period, byte frequency) =>
        new(0x27, startZone, (byte)(behaviorFlag > 0 ? 0x02 : 0x01), (byte)((force << 4) | (amplitude & 0x0F)), period, frequency);

    public static TriggerEffect Custom(byte[] tenRawBytes)
    {
        if (tenRawBytes.Length != 10)
        {
            throw new ArgumentException("Custom trigger effects require exactly 10 raw bytes.", nameof(tenRawBytes));
        }

        return new TriggerEffect(0xFF, tenRawBytes);
    }

    /// <summary>
    /// Writes this effect's mode + parameter bytes into <paramref name="output"/> at [offset..offset+9],
    /// mirroring FGamepadOutput::SetTriggerEffects byte-for-byte (each mode has its own zero-fill footprint).
    /// </summary>
    public readonly void WriteTo(byte[] output, int offset)
    {
        output[offset] = Mode;

        switch (Mode)
        {
            case 0xFF:
                Array.Copy(Compose, 0, output, offset, 10);
                break;
            case 0x00:
                for (var i = 1; i <= 9; i++) output[offset + i] = 0x00;
                break;
            case 0x01:
                // Upstream only ever writes bytes 1-2 for this mode; 3-9 are left as whatever was already buffered.
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                break;
            case 0x02:
            case 0x22:
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                output[offset + 3] = Compose[2];
                output[offset + 4] = Compose[3];
                output[offset + 5] = Compose[4];
                for (var i = 6; i <= 9; i++) output[offset + i] = 0x00;
                break;
            case 0x23:
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                output[offset + 3] = Compose[2];
                output[offset + 4] = Compose[3];
                for (var i = 5; i <= 9; i++) output[offset + i] = 0x00;
                break;
            case 0x25:
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                output[offset + 3] = Compose[2];
                for (var i = 4; i <= 9; i++) output[offset + i] = 0x00;
                break;
            case 0x26:
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                output[offset + 3] = Compose[2];
                output[offset + 4] = Compose[3];
                output[offset + 5] = Compose[4];
                output[offset + 6] = Compose[5];
                output[offset + 7] = 0x00;
                output[offset + 8] = 0x00;
                output[offset + 9] = Compose[9];
                break;
            case 0x27:
                output[offset + 1] = Compose[0];
                output[offset + 2] = Compose[1];
                output[offset + 3] = Compose[2];
                output[offset + 4] = Compose[3];
                output[offset + 5] = Compose[4];
                for (var i = 6; i <= 9; i++) output[offset + i] = 0x00;
                break;
        }
    }
}
