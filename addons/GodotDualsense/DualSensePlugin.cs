#if TOOLS
using Godot;

namespace GodotDualsense;

[Tool]
public partial class DualSensePlugin : EditorPlugin
{
    private const string AutoloadName = "DualSenseManager";
    private const string AutoloadPath = "res://addons/GodotDualsense/DualSenseManager.cs";

    public override void _EnterTree()
    {
        AddAutoloadSingleton(AutoloadName, AutoloadPath);
    }

    public override void _ExitTree()
    {
        RemoveAutoloadSingleton(AutoloadName);
    }
}
#endif
