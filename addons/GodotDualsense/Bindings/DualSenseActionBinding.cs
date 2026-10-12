using Godot;

namespace GodotDualsense.Bindings;

/// <summary>
/// Maps one DualSense input (an analog trigger, the touchpad, or any digital button) onto a Godot
/// input action, so the rest of the game just reads it through the normal <c>Input</c> API. If
/// <see cref="Source"/> is a trigger and <see cref="TriggerProfile"/> is set, that adaptive-trigger
/// effect is applied to the matching hand for as long as this binding is active.
/// </summary>
[GlobalClass, Icon("res://addons/GodotDualsense/logo.png")]
public partial class DualSenseActionBinding : Resource
{
    [Export]
    public StringName Action { get; set; } = "";

    [Export]
    public DualSenseInputSource Source { get; set; } = DualSenseInputSource.LeftTriggerAnalog;

    /// <summary>Analog sources (the triggers) count as "pressed" once they cross this fraction of full pull.</summary>
    [Export(PropertyHint.Range, "0,1,0.01")]
    public float Threshold { get; set; } = 0.5f;

    /// <summary>Only meaningful when <see cref="Source"/> is LeftTriggerAnalog or RightTriggerAnalog.</summary>
    [Export]
    public DualSenseTriggerProfile TriggerProfile { get; set; }
}
