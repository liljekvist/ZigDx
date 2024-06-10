const zwin32 = @import("zwin32");
const w32 = zwin32.w32;

const Dx12State = @import("util/DxState.zig").Dx12State;
const helpers = @import("util/helpers.zig");
const render = @import("render.zig");

pub export const D3D12SDKVersion: u32 = 610;
pub export const D3D12SDKPath: [*:0]const u8 = ".\\d3d12\\";

const window_name = "test"; // export cont pub

pub fn main() !u8 {
    const ret = try helpers.initializeWindowAndDx12(window_name);
    var dx12 = ret.dx12;
    const window = ret.window;
    defer dx12.deinit();
    defer w32.CoUninitialize();

    const ret2 = try helpers.createRootSignatureAndPipeline(&dx12);
    const root_signature = ret2.root_signature;
    const pipeline = ret2.pipeline;
    defer _ = pipeline.Release();
    defer _ = root_signature.Release();

    try render.render_loop(&dx12, window, root_signature, pipeline);

    dx12.finishGpuCommands();

    return 0;
}
