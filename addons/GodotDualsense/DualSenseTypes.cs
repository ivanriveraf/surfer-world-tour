namespace GodotDualsense;

public enum DualSenseHand
{
    Left,
    Right,
    Both,
}

public enum DualSensePlayer
{
    Off = 0x00,
    One = Protocol.DualSenseProtocol.LedMasks.Middle,
    Two = Protocol.DualSenseProtocol.LedMasks.MiddleRight | Protocol.DualSenseProtocol.LedMasks.MiddleLeft,
    Three = Protocol.DualSenseProtocol.LedMasks.Right | Protocol.DualSenseProtocol.LedMasks.Middle | Protocol.DualSenseProtocol.LedMasks.Left,
    All = Protocol.DualSenseProtocol.LedMasks.Right | Protocol.DualSenseProtocol.LedMasks.MiddleRight |
          Protocol.DualSenseProtocol.LedMasks.MiddleLeft | Protocol.DualSenseProtocol.LedMasks.Left,
}

public enum DualSenseMic
{
    On = 0,
    Off = 1,
    Pulse = 2,
}

public enum DualSenseButton
{
    Cross,
    Square,
    Circle,
    Triangle,
    DpadUp,
    DpadDown,
    DpadLeft,
    DpadRight,
    L1,
    R1,
    L3,
    R3,
    L2Threshold,
    R2Threshold,
    Share,
    Options,
    PS,
    TouchpadClick,
    Mute,
    Fn1,
    Fn2,
    PaddleLeft,
    PaddleRight,
}

/// <summary>Adaptive-trigger effect families a <see cref="Bindings.DualSenseTriggerProfile"/> can configure.</summary>
public enum DualSenseTriggerEffectType
{
    Off,
    GameCube,
    Resistance,
    Bow,
    Galloping,
    Weapon,
    MachineGun,
    Machine,
}

/// <summary>
/// Anything a <see cref="Bindings.DualSenseActionBinding"/> can read: the two analog triggers,
/// whether a finger is on the touchpad, or any digital button (including ones Godot's InputMap
/// can't normally reach, like Mute/PS/paddles).
/// </summary>
public enum DualSenseInputSource
{
    LeftTriggerAnalog,
    RightTriggerAnalog,
    TouchpadTouching,
    Cross,
    Square,
    Circle,
    Triangle,
    DpadUp,
    DpadDown,
    DpadLeft,
    DpadRight,
    L1,
    R1,
    L3,
    R3,
    L2Threshold,
    R2Threshold,
    Share,
    Options,
    PS,
    TouchpadClick,
    Mute,
    Fn1,
    Fn2,
    PaddleLeft,
    PaddleRight,
}
