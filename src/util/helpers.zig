const std = @import("std");
const zwin32 = @import("zwin32");
const w32 = zwin32.w32;
const d3d12 = zwin32.d3d12;
const d3d12d = zwin32.d3d12d;
const hrPanicOnFail = zwin32.hrPanicOnFail;

const Dx12State = @import("DxState.zig").Dx12State;

pub fn processWindowMessage(
    window: w32.HWND,
    message: w32.UINT,
    wparam: w32.WPARAM,
    lparam: w32.LPARAM,
) callconv(w32.WINAPI) w32.LRESULT {
    switch (message) {
        w32.WM_KEYDOWN => {
            if (wparam == w32.VK_ESCAPE) {
                w32.PostQuitMessage(0);
                return 0;
            }
        },
        w32.WM_GETMINMAXINFO => {
            var info: *w32.MINMAXINFO = @ptrFromInt(@as(usize, @intCast(lparam)));
            info.ptMinTrackSize.x = 400;
            info.ptMinTrackSize.y = 400;
            return 0;
        },
        w32.WM_DESTROY => {
            w32.PostQuitMessage(0);
            return 0;
        },
        else => {},
    }
    return w32.DefWindowProcA(window, message, wparam, lparam);
}

pub fn createWindow(width: u32, height: u32, window_name: [*:0]const u8) w32.HWND {
    const winclass = w32.WNDCLASSEXA{
        .style = 0,
        .lpfnWndProc = processWindowMessage,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hInstance = @ptrCast(w32.GetModuleHandleA(null)),
        .hIcon = null,
        .hCursor = w32.LoadCursorA(null, @ptrFromInt(32512)),
        .hbrBackground = null,
        .lpszMenuName = null,
        .lpszClassName = window_name,
        .hIconSm = null,
    };
    _ = w32.RegisterClassExA(&winclass);

    const style = w32.WS_OVERLAPPEDWINDOW;

    var rect = w32.RECT{
        .left = 0,
        .top = 0,
        .right = @intCast(width),
        .bottom = @intCast(height),
    };
    _ = w32.AdjustWindowRectEx(&rect, style, w32.FALSE, 0);

    const window = w32.CreateWindowExA(
        0,
        window_name,
        window_name,
        style + w32.WS_VISIBLE,
        w32.CW_USEDEFAULT,
        w32.CW_USEDEFAULT,
        rect.right - rect.left,
        rect.bottom - rect.top,
        null,
        null,
        winclass.hInstance,
        null,
    ).?;

    std.log.info("Application window created", .{});

    return window;
}

pub fn initializeWindowAndDx12(window_name: [*:0]const u8) !struct {dx12: Dx12State, window: w32.HWND} {
    _ = w32.CoInitializeEx(null, w32.COINIT_MULTITHREADED);
    _ = w32.SetProcessDPIAware();

    const window = createWindow(1600, 1200, window_name);

    return .{.dx12 = Dx12State.init(window), .window = window};
}

pub fn createRootSignatureAndPipeline(dx12: *Dx12State) !struct {root_signature: *d3d12.IRootSignature, pipeline: *d3d12.IPipelineState} {
    const vs_cso = @embedFile("./../content/ZigDx.vs.cso");
    const ps_cso = @embedFile("./../content/ZigDx.ps.cso");

    var pso_desc = d3d12.GRAPHICS_PIPELINE_STATE_DESC.initDefault();
    pso_desc.DepthStencilState.DepthEnable = w32.FALSE;
    pso_desc.RTVFormats[0] = .R8G8B8A8_UNORM;
    pso_desc.NumRenderTargets = 1;
    pso_desc.PrimitiveTopologyType = .TRIANGLE;
    pso_desc.VS = .{ .pShaderBytecode = vs_cso, .BytecodeLength = vs_cso.len };
    pso_desc.PS = .{ .pShaderBytecode = ps_cso, .BytecodeLength = ps_cso.len };

    var root_signature: *d3d12.IRootSignature = undefined;
    hrPanicOnFail(dx12.device.CreateRootSignature(
        0,
        pso_desc.VS.pShaderBytecode.?,
        pso_desc.VS.BytecodeLength,
        &d3d12.IID_IRootSignature,
        @ptrCast(&root_signature),
    ));

    var pipeline: *d3d12.IPipelineState = undefined;
    hrPanicOnFail(dx12.device.CreateGraphicsPipelineState(
        &pso_desc,
        &d3d12.IID_IPipelineState,
        @ptrCast(&pipeline),
    ));

    return .{ .root_signature = root_signature, .pipeline = pipeline };
}