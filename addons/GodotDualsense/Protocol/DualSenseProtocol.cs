namespace GodotDualsense.Protocol;

/// <summary>
/// USB VID/PID and wire-format constants for the DualSense HID protocol.
/// Ported from Rafael Valoto's Dualsense-Multiplatform (MIT license).
/// </summary>
public static class DualSenseProtocol
{
    public const int SonyVendorId = 0x054C;
    public const int DualSenseProductId = 0x0CE6;
    public const int DualSenseEdgeProductId = 0x0DF2;

    public const byte UsbInputReportId = 0x01;
    public const byte BluetoothInputReportId = 0x31;

    public const byte UsbOutputReportId = 0x02;
    public const byte BluetoothOutputReportId = 0x31;

    /// <summary>Byte offset of the input payload after the report-ID byte(s): 1 over USB, 2 over Bluetooth.</summary>
    public const int UsbInputPadding = 1;
    public const int BluetoothInputPadding = 2;

    /// <summary>Scratch output buffer size; large enough to hold the Bluetooth report + trailing CRC32.</summary>
    public const int OutputBufferSize = 78;

    /// <summary>CRC32 is computed over the first 74 bytes of the Bluetooth output report.</summary>
    public const int BluetoothCrcLength = 74;

    public static class InputMasks
    {
        public static class Face
        {
            public const byte Square = 0x10;
            public const byte Cross = 0x20;
            public const byte Circle = 0x40;
            public const byte Triangle = 0x80;
        }

        public static class DPad
        {
            public const byte Up = 0x08;
            public const byte Right = 0x04;
            public const byte Down = 0x02;
            public const byte Left = 0x01;
        }

        public static class Shoulder
        {
            public const byte L1 = 0x01;
            public const byte R1 = 0x02;
            public const byte L2 = 0x04;
            public const byte R2 = 0x08;
        }

        public static class Menu
        {
            public const byte Share = 0x10;
            public const byte Options = 0x20;
            public const byte PS = 0x01;
            public const byte TouchPad = 0x02;
            public const byte Mute = 0x04;
        }

        public static class Stick
        {
            public const byte L3 = 0x40;
            public const byte R3 = 0x80;
        }

        public static class Extra
        {
            public const byte FnLeft = 0x10;
            public const byte FnRight = 0x20;
            public const byte PaddleLeft = 0x40;
            public const byte PaddleRight = 0x80;
        }
    }

    public static class LedMasks
    {
        public const byte Left = 0x01;
        public const byte MiddleLeft = 0x02;
        public const byte Middle = 0x04;
        public const byte MiddleRight = 0x08;
        public const byte Right = 0x10;
    }
}
