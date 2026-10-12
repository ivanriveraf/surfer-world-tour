using Godot;

namespace GodotDualsense.Bindings;

/// <summary>
/// Editor-configurable adaptive-trigger effect: pick a <see cref="DualSenseTriggerEffectType"/> and
/// tune only the fields that effect uses. Reusable/shareable as a .tres across bindings or hands.
/// </summary>
[GlobalClass, Icon("res://addons/GodotDualsense/logo.png")]
public partial class DualSenseTriggerProfile : Resource
{
    [Export]
    public DualSenseTriggerEffectType EffectType { get; set; } = DualSenseTriggerEffectType.Off;

    [ExportGroup("Parameters")]
    [Export(PropertyHint.Range, "0,15")]
    public byte StartZone { get; set; }

    [Export]
    public byte Strength { get; set; }

    [Export]
    public byte SnapBack { get; set; }

    [Export(PropertyHint.Range, "0,9")]
    public byte EndPosition { get; set; } = 9;

    [Export(PropertyHint.Range, "0,8")]
    public byte FirstFoot { get; set; }

    [Export(PropertyHint.Range, "0,8")]
    public byte SecondFoot { get; set; }

    [Export(PropertyHint.Range, "0,15")]
    public byte Amplitude { get; set; }

    [Export]
    public byte Behavior { get; set; }

    [Export(PropertyHint.Range, "0,15")]
    public byte TriggerValue { get; set; }

    [Export(PropertyHint.Range, "0,15")]
    public byte Force { get; set; }

    [Export]
    public byte Period { get; set; }

    [Export]
    public byte Frequency { get; set; }

    public void Apply(DualSenseManager manager, DualSenseHand hand)
    {
        switch (EffectType)
        {
            case DualSenseTriggerEffectType.Off:
                manager.SetTriggerOff(hand);
                break;
            case DualSenseTriggerEffectType.GameCube:
                manager.SetTriggerGameCube(hand);
                break;
            case DualSenseTriggerEffectType.Resistance:
                manager.SetTriggerResistance(StartZone, Strength, hand);
                break;
            case DualSenseTriggerEffectType.Bow:
                manager.SetTriggerBow(StartZone, SnapBack, hand);
                break;
            case DualSenseTriggerEffectType.Galloping:
                manager.SetTriggerGalloping(StartZone, EndPosition, FirstFoot, SecondFoot, Frequency, hand);
                break;
            case DualSenseTriggerEffectType.Weapon:
                manager.SetTriggerWeapon(StartZone, Amplitude, Behavior, TriggerValue, hand);
                break;
            case DualSenseTriggerEffectType.MachineGun:
                manager.SetTriggerMachineGun(StartZone, Behavior, Amplitude, Frequency, hand);
                break;
            case DualSenseTriggerEffectType.Machine:
                manager.SetTriggerMachine(StartZone, Behavior, Force, Amplitude, Period, Frequency, hand);
                break;
        }
    }
}
