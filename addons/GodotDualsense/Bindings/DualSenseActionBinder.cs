using GodotDualsense.Protocol;
using Godot;
using Godot.Collections;

namespace GodotDualsense.Bindings;

/// <summary>
/// Drives a list of <see cref="DualSenseActionBinding"/>s: each frame, reads the bound DualSense
/// input and calls <see cref="Input.ActionPress"/>/<see cref="Input.ActionRelease"/> on its target
/// action, so gameplay code never needs to know the input came from a DualSense at all. Applies any
/// configured adaptive-trigger profiles once on connect.
/// </summary>
[GlobalClass, Icon("res://addons/GodotDualsense/logo.png")]
public partial class DualSenseActionBinder : Node
{
    [Export]
    public Array<DualSenseActionBinding> Bindings { get; set; } = new();

    private bool[] _pressed = System.Array.Empty<bool>();

    public DualSenseActionBinder()
    {
        // Must run before other gameplay nodes' _PhysicsProcess (e.g. PlayerInputComponent) in the
        // same tick, so Input.IsActionJustPressed sees the edge on the same physics frame it fires.
        ProcessPhysicsPriority = -100;
    }

    public override void _Ready()
    {
        _pressed = new bool[Bindings.Count];

        DualSenseManager manager = DualSenseManager.Instance;
        if (manager == null)
            return;

        if (manager.IsControllerConnected)
            ApplyTriggerProfiles(manager);
        manager.ControllerConnected += () => ApplyTriggerProfiles(DualSenseManager.Instance);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (DualSenseManager.Instance is not { IsControllerConnected: true } manager)
            return;

        DualSenseInputState state = manager.State;
        for (int i = 0; i < Bindings.Count; i++)
        {
            DualSenseActionBinding binding = Bindings[i];
            if (binding == null || string.IsNullOrEmpty(binding.Action))
                continue;

            float strength = ReadSourceValue(state, binding.Source);
            bool pressed = strength >= binding.Threshold;

            if (pressed)
                Input.ActionPress(binding.Action, strength);
            else if (_pressed[i])
                Input.ActionRelease(binding.Action);

            _pressed[i] = pressed;
        }
    }

    private void ApplyTriggerProfiles(DualSenseManager manager)
    {
        if (manager == null)
            return;

        foreach (DualSenseActionBinding binding in Bindings)
        {
            if (binding?.TriggerProfile == null)
                continue;

            if (binding.Source == DualSenseInputSource.LeftTriggerAnalog)
                binding.TriggerProfile.Apply(manager, DualSenseHand.Left);
            else if (binding.Source == DualSenseInputSource.RightTriggerAnalog)
                binding.TriggerProfile.Apply(manager, DualSenseHand.Right);
        }
    }

    private static float ReadSourceValue(DualSenseInputState state, DualSenseInputSource source) => source switch
    {
        DualSenseInputSource.LeftTriggerAnalog => state.LeftTrigger,
        DualSenseInputSource.RightTriggerAnalog => state.RightTrigger,
        DualSenseInputSource.TouchpadTouching => state.IsTouching ? 1f : 0f,
        DualSenseInputSource.Cross => state.Cross ? 1f : 0f,
        DualSenseInputSource.Square => state.Square ? 1f : 0f,
        DualSenseInputSource.Circle => state.Circle ? 1f : 0f,
        DualSenseInputSource.Triangle => state.Triangle ? 1f : 0f,
        DualSenseInputSource.DpadUp => state.DpadUp ? 1f : 0f,
        DualSenseInputSource.DpadDown => state.DpadDown ? 1f : 0f,
        DualSenseInputSource.DpadLeft => state.DpadLeft ? 1f : 0f,
        DualSenseInputSource.DpadRight => state.DpadRight ? 1f : 0f,
        DualSenseInputSource.L1 => state.L1 ? 1f : 0f,
        DualSenseInputSource.R1 => state.R1 ? 1f : 0f,
        DualSenseInputSource.L3 => state.L3 ? 1f : 0f,
        DualSenseInputSource.R3 => state.R3 ? 1f : 0f,
        DualSenseInputSource.L2Threshold => state.L2Threshold ? 1f : 0f,
        DualSenseInputSource.R2Threshold => state.R2Threshold ? 1f : 0f,
        DualSenseInputSource.Share => state.Share ? 1f : 0f,
        DualSenseInputSource.Options => state.Options ? 1f : 0f,
        DualSenseInputSource.PS => state.PS ? 1f : 0f,
        DualSenseInputSource.TouchpadClick => state.TouchpadClick ? 1f : 0f,
        DualSenseInputSource.Mute => state.Mute ? 1f : 0f,
        DualSenseInputSource.Fn1 => state.Fn1 ? 1f : 0f,
        DualSenseInputSource.Fn2 => state.Fn2 ? 1f : 0f,
        DualSenseInputSource.PaddleLeft => state.PaddleLeft ? 1f : 0f,
        DualSenseInputSource.PaddleRight => state.PaddleRight ? 1f : 0f,
        _ => 0f,
    };
}
