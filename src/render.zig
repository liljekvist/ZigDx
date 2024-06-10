const std = @import("std");
const zwin32 = @import("zwin32");
const w32 = zwin32.w32;
const d3d12 = zwin32.d3d12;
const d3d12d = zwin32.d3d12d;
const hrPanicOnFail = zwin32.hrPanicOnFail;

const Dx12State = @import("util/DxState.zig").Dx12State;

pub fn render_loop(dx12: *Dx12State, window: w32.HWND, root_signature: *d3d12.IRootSignature, pipeline: *d3d12.IPipelineState) !void {
    var window_rect: w32.RECT = undefined;
    _ = w32.GetClientRect(window, &window_rect);

    var frac: f32 = 0.0;
    var frac_delta: f32 = 0.01;

    var frac2: f32 = 0.5;
    var frac2_delta: f32 = 0.01;

    var frac3: f32 = 0.0;
    var frac3_delta: f32 = -0.01;

    main_loop: while (true) {
        {
            var message = std.mem.zeroes(w32.MSG);
            while (w32.PeekMessageA(&message, null, 0, 0, w32.PM_REMOVE) == w32.TRUE) {
                _ = w32.TranslateMessage(&message);
                _ = w32.DispatchMessageA(&message);
                if (message.message == w32.WM_QUIT) {
                    break :main_loop;
                }
            }

            var rect: w32.RECT = undefined;
            _ = w32.GetClientRect(window, &rect);
            if (rect.right == 0 and rect.bottom == 0) {
                // Window is minimized
                w32.Sleep(10);
                continue :main_loop;
            }

            if (rect.right != window_rect.right or rect.bottom != window_rect.bottom) {
                rect.right = @max(1, rect.right);
                rect.bottom = @max(1, rect.bottom);
                std.log.info("Window resized to {d}x{d}", .{ rect.right, rect.bottom });

                dx12.finishGpuCommands();

                for (dx12.swap_chain_textures) |texture| _ = texture.Release();

                hrPanicOnFail(dx12.swap_chain.ResizeBuffers(0, 0, 0, .UNKNOWN, .{}));

                for (&dx12.swap_chain_textures, 0..) |*texture, i| {
                    hrPanicOnFail(dx12.swap_chain.GetBuffer(
                        @intCast(i),
                        &d3d12.IID_IResource,
                        @ptrCast(&texture.*),
                    ));
                }

                for (dx12.swap_chain_textures, 0..) |texture, i| {
                    dx12.device.CreateRenderTargetView(
                        texture,
                        null,
                        .{ .ptr = dx12.rtv_heap_start.ptr +
                        i * dx12.device.GetDescriptorHandleIncrementSize(.RTV) },
                    );
                }
            }
            window_rect = rect;
        }

        const command_allocator = dx12.command_allocators[dx12.frame_index];

        hrPanicOnFail(command_allocator.Reset());
        hrPanicOnFail(dx12.command_list.Reset(command_allocator, null));

        dx12.command_list.RSSetViewports(1, &.{
            .{
                .TopLeftX = 0.0,
                .TopLeftY = 0.0,
                .Width = @floatFromInt(window_rect.right),
                .Height = @floatFromInt(window_rect.bottom),
                .MinDepth = 0.0,
                .MaxDepth = 1.0,
            },
        });
        dx12.command_list.RSSetScissorRects(1, &.{
            .{
                .left = 0,
                .top = 0,
                .right = @intCast(window_rect.right),
                .bottom = @intCast(window_rect.bottom),
            },
        });

        const back_buffer_index = dx12.swap_chain.GetCurrentBackBufferIndex();
        const back_buffer_descriptor = d3d12.CPU_DESCRIPTOR_HANDLE{
            .ptr = dx12.rtv_heap_start.ptr +
            back_buffer_index * dx12.device.GetDescriptorHandleIncrementSize(.RTV),
        };

        dx12.command_list.ResourceBarrier(1, &.{
            .{
                .Type = .TRANSITION,
                .Flags = .{},
                .u = .{
                    .Transition = .{
                        .pResource = dx12.swap_chain_textures[back_buffer_index],
                        .Subresource = d3d12.RESOURCE_BARRIER_ALL_SUBRESOURCES,
                        .StateBefore = d3d12.RESOURCE_STATES.PRESENT,
                        .StateAfter = .{ .RENDER_TARGET = true },
                    },
                },
            },
        });

        dx12.command_list.OMSetRenderTargets(
            1,
            &.{back_buffer_descriptor},
            w32.TRUE,
            null,
        );
        dx12.command_list.ClearRenderTargetView(back_buffer_descriptor, &.{ frac, frac2, frac3, 1.0 }, 0, null);

        dx12.command_list.IASetPrimitiveTopology(.TRIANGLELIST);
        dx12.command_list.SetPipelineState(pipeline);
        dx12.command_list.SetGraphicsRootSignature(root_signature);
        dx12.command_list.DrawInstanced(3, 1, 0, 0);

        dx12.command_list.ResourceBarrier(1, &.{
            .{
                .Type = .TRANSITION,
                .Flags = .{},
                .u = .{
                    .Transition = .{
                        .pResource = dx12.swap_chain_textures[back_buffer_index],
                        .Subresource = d3d12.RESOURCE_BARRIER_ALL_SUBRESOURCES,
                        .StateBefore = .{ .RENDER_TARGET = true },
                        .StateAfter = d3d12.RESOURCE_STATES.PRESENT,
                    },
                },
            },
        });
        hrPanicOnFail(dx12.command_list.Close());

        dx12.command_queue.ExecuteCommandLists(1, &.{@ptrCast(dx12.command_list)});

        dx12.present();

        frac += frac_delta;
        if (frac > 1.0 or frac < 0.0) {
            frac_delta = -frac_delta;
        }

        frac2 += frac2_delta;
        if (frac2 > 1.0 or frac2 < 0.0) {
            frac2_delta = -frac2_delta;
        }

        frac3 += frac3_delta;
        if (frac3 > 1.0 or frac3 < 0.0) {
            frac3_delta = -frac3_delta;
        }
    }
}