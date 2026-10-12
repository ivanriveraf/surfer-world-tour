using System;
using Godot;

namespace GodotDualsense.Protocol;

/// <summary>
/// Snapshot of one DualSense input report. Ported from Dualsense-Multiplatform's
/// FGamepadInput::DualSenseRaw / FGamepadTouch::ProcessTouchDualSense.
/// </summary>
public struct DualSenseInputState
{
    public Vector2 LeftStick;
    public Vector2 RightStick;
    public float LeftTrigger;
    public float RightTrigger;

    public Vector3 Gyroscope;
    public Vector3 Accelerometer;

    public bool IsTouching;
    public int TouchFingerCount;
    public Vector2 TouchPosition;

    public bool Cross, Square, Circle, Triangle;
    public bool DpadUp, DpadDown, DpadLeft, DpadRight;
    public bool L1, R1, L3, R3;
    public bool L2Threshold, R2Threshold;
    public bool Share, Options, PS, TouchpadClick, Mute;
    public bool Fn1, Fn2, PaddleLeft, PaddleRight;

    public float BatteryLevel;
    public bool PhoneConnected;

    private const float AnalogDeadZone = 0.08f;

    /// <summary>Parses one report; <paramref name="input"/> must start at the byte after the report-ID header.</summary>
    public static DualSenseInputState Parse(ReadOnlySpan<byte> input)
    {
        var state = new DualSenseInputState();

        var leftX = ApplyDeadZone((input[0x00] - 128) / 128f);
        var leftY = ApplyDeadZone((input[0x01] - 128) / -128f);
        var rightX = ApplyDeadZone((input[0x02] - 128) / 128f);
        var rightY = ApplyDeadZone((input[0x03] - 128) / -128f);
        state.LeftStick = new Vector2(leftX, leftY);
        state.RightStick = new Vector2(rightX, rightY);

        state.LeftTrigger = input[0x04] / 256f;
        state.RightTrigger = input[0x05] / 256f;

        var faceMask = (byte)(input[0x07] & 0xF0);
        state.Square = (faceMask & DualSenseProtocol.InputMasks.Face.Square) != 0;
        state.Cross = (faceMask & DualSenseProtocol.InputMasks.Face.Cross) != 0;
        state.Circle = (faceMask & DualSenseProtocol.InputMasks.Face.Circle) != 0;
        state.Triangle = (faceMask & DualSenseProtocol.InputMasks.Face.Triangle) != 0;

        // D-pad is a single 8-way nibble (0=Up .. clockwise), not a bitmask.
        switch (input[0x07] & 0x0F)
        {
            case 0x0: state.DpadUp = true; break;
            case 0x1: state.DpadUp = true; state.DpadRight = true; break;
            case 0x2: state.DpadRight = true; break;
            case 0x3: state.DpadRight = true; state.DpadDown = true; break;
            case 0x4: state.DpadDown = true; break;
            case 0x5: state.DpadDown = true; state.DpadLeft = true; break;
            case 0x6: state.DpadLeft = true; break;
            case 0x7: state.DpadLeft = true; state.DpadUp = true; break;
        }

        var btn8 = input[0x08];
        state.L1 = (btn8 & DualSenseProtocol.InputMasks.Shoulder.L1) != 0;
        state.R1 = (btn8 & DualSenseProtocol.InputMasks.Shoulder.R1) != 0;
        state.L2Threshold = (btn8 & DualSenseProtocol.InputMasks.Shoulder.L2) != 0;
        state.R2Threshold = (btn8 & DualSenseProtocol.InputMasks.Shoulder.R2) != 0;
        state.Share = (btn8 & DualSenseProtocol.InputMasks.Menu.Share) != 0;
        state.Options = (btn8 & DualSenseProtocol.InputMasks.Menu.Options) != 0;
        state.L3 = (btn8 & DualSenseProtocol.InputMasks.Stick.L3) != 0;
        state.R3 = (btn8 & DualSenseProtocol.InputMasks.Stick.R3) != 0;

        var btn9 = input[0x09];
        state.PS = (btn9 & DualSenseProtocol.InputMasks.Menu.PS) != 0;
        state.TouchpadClick = (btn9 & DualSenseProtocol.InputMasks.Menu.TouchPad) != 0;
        state.Mute = (btn9 & DualSenseProtocol.InputMasks.Menu.Mute) != 0;
        state.Fn1 = (btn9 & DualSenseProtocol.InputMasks.Extra.FnLeft) != 0;
        state.Fn2 = (btn9 & DualSenseProtocol.InputMasks.Extra.FnRight) != 0;
        state.PaddleLeft = (btn9 & DualSenseProtocol.InputMasks.Extra.PaddleLeft) != 0;
        state.PaddleRight = (btn9 & DualSenseProtocol.InputMasks.Extra.PaddleRight) != 0;

        var rawGyroX = (short)(input[0x0F] | (input[0x10] << 8));
        var rawGyroY = (short)(input[0x11] | (input[0x12] << 8));
        var rawGyroZ = (short)(input[0x13] | (input[0x14] << 8));
        var rawAccX = (short)(input[0x15] | (input[0x16] << 8));
        var rawAccY = (short)(input[0x17] | (input[0x18] << 8));
        var rawAccZ = (short)(input[0x19] | (input[0x1A] << 8));

        // Fixed factory-typical scale (no per-device calibration report read): deg/s and g respectively.
        const float gyroResPerDegS = 1024f;
        const float accelResPerG = 8192f;
        state.Gyroscope = new Vector3(rawGyroX, rawGyroY, rawGyroZ) / gyroResPerDegS;
        state.Accelerometer = new Vector3(rawAccX, rawAccY, rawAccZ) / accelResPerG;

        state.IsTouching = (input[0x20] & 0x80) == 0;
        var touchX = ((input[0x22] & 0x0F) << 8) | input[0x21];
        var touchY = (input[0x23] << 4) | ((input[0x22] & 0xF0) >> 4);
        state.TouchPosition = new Vector2(touchX, touchY);
        state.TouchFingerCount = state.IsTouching && (input[0x24] & 0x80) == 0 ? 2 : 1;

        state.BatteryLevel = (input[0x34] & 0x0F) / 10f * 100f;
        state.PhoneConnected = (input[0x35] & 0x01) != 0;

        return state;
    }

    private static float ApplyDeadZone(float value)
    {
        if (MathF.Abs(value) < AnalogDeadZone)
        {
            return 0f;
        }

        var sign = value >= 0f ? 1f : -1f;
        return sign * ((MathF.Abs(value) - AnalogDeadZone) / (1f - AnalogDeadZone));
    }
}
