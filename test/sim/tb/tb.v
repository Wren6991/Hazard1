/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Hardware component of Hazard1 execution testbench

`default_nettype none

module tb (
	input  wire         clk,
	input  wire         rst_n,

	output wire  [31:0] mem_addr,
	output wire  [3:0]  mem_wen,
	output wire         mem_ren,
	output wire  [31:0] mem_wdata,
	input  wire  [31:0] mem_rdata,
	input  wire         mem_stall
);

// Simple passthrough for now

hazard1 #(
	.REGS_BASE    (32'h00),
	.RESET_VECTOR (32'h80)
) cpu (
	.clk       (clk),
	.rst_n     (rst_n),
	.mem_addr  (mem_addr),
	.mem_wen   (mem_wen),
	.mem_ren   (mem_ren),
	.mem_wdata (mem_wdata),
	.mem_rdata (mem_rdata),
	.mem_stall (mem_stall)
);

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
