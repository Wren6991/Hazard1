/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Hazard1: a minimal RV32I processor with registers in RAM.

`default_nettype none

module hazard1 #(
	parameter REGS_BASE    = 32'h00000000,
	parameter RESET_VECTOR = 32'h00000080
) (
	input  wire         clk,
	input  wire         rst_n,

	output wire  [31:0] mem_addr,
	output wire  [3:0]  mem_wen,
	output wire         mem_ren,
	output wire  [31:0] mem_wdata,
	input  wire  [31:0] mem_rdata,
	input  wire         mem_stall
);

`include "rv_opcodes.vh"

reg [31:0] pc;
reg [31:0] cir;
reg [31:0] rs1;
reg [31:0] rs2;
reg [2:0]  state;

// ----------------------------------------------------------------------------
// Control and decode

reg [31:0] pc_nxt;
reg [31:0] cir_nxt;
reg [31:0] rs1_nxt;
reg [31:0] rs2_nxt;
reg [2:0]  state_nxt;

wire [RV_OPC_BITS-1:0]    cir_opc    = cir[RV_OPC_LSB    +: RV_OPC_BITS   ];
wire [RV_RD_BITS-1:0]     cir_rd     = cir[RV_RD_LSB     +: RV_RD_BITS    ];
wire [RV_FUNCT3_BITS-1:0] cir_funct3 = cir[RV_FUNCT3_LSB +: RV_FUNCT3_BITS];
wire [RV_RS1_BITS-1:0]    cir_rs1    = cir[RV_RS1_LSB    +: RV_RS1_BITS   ];
wire [RV_RS2_BITS-1:0]    cir_rs2    = cir[RV_RS2_LSB    +: RV_RS2_BITS   ];
wire [RV_FUNCT7_BITS-1:0] cir_funct7 = cir[RV_FUNCT7_LSB +: RV_FUNCT7_BITS];

wire [31:0] imm_i = {{21{cir[31]}}, cir[30:20]};
wire [31:0] imm_s = {{21{cir[31]}}, cir[30:25], cir[11:7]};
wire [31:0] imm_b = {{20{cir[31]}}, cir[7], cir[30:25], cir[11:8], 1'b0};
wire [31:0] imm_u = {cir[31:12], {12{1'b0}}};
wire [31:0] imm_j = {{12{cir[31]}}, cir[19:12], cir[20], cir[30:21], 1'b0};

function [31:0] reg_addr;
	input [4:0] regnum;
begin
	reg_addr = {REGS_BASE[31:7], regnum, 2'h0};
end endfunction

 // Note the "rs2" reg is used for addresses (even though this is always a
 // read of rs1 from the register file) to make it cheaper to re-use the
 // shifter to align load/store data.

wire branch_true;
wire [31:0] address_adder =
	cir_opc == RV_OPC_JAL                   ? pc  + imm_j :
	cir_opc == RV_OPC_BRANCH && branch_true ? pc  + imm_b :
	cir_opc == RV_OPC_LOAD && !state[0]     ? rs2 + imm_i :
	cir_opc == RV_OPC_JALR                  ? rs2 + imm_i : 
	cir_opc == RV_OPC_STORE                 ? rs2 + imm_s : pc + 32'd4;

always @ (*) begin
	pc_nxt = pc;
	cir_nxt = cir;
	rs1_nxt = rs1;
	rs2_nxt = rs2;
	state_nxt = state + 3'd1;

	mem_addr = 32'h0;
	mem_ren = 1'b0;
	mem_wen = 4'h0;

	case (cir_opc)

		RV_OPC_OP: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rs2);
				mem_ren = |cir_rs2;
				rs1_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd2: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs2_nxt = mem_rdata & {32{|cir_rs2}};
			end
			3'd3: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen	= 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_OP_IMM: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
				rs2_nxt = imm_i;
			end
			3'd1: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs1_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd2: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_LUI: case (state)
			3'd0: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs2_nxt = imm_u;
				rs1_nxt = 32'd0;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_AUIPC: case (state)
			3'd0: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs1_nxt = pc;
				rs2_nxt = imm_u;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_LOAD: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
			end
			3'd1: begin
				// (Wasted SRAM cycle here -- we could avoid it, by hoisting
				// the next instruction fetch, at the cost of a few flops)
				rs1_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd2: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
			end
			3'd3: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				rs1_nxt = mem_rdata;
				pc_nxt = address_adder;
			end
			3'd4: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_STORE: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rs2);
				mem_ren = |cir_rs2;
				// Swap rs2/rs1 (free) because it makes use of the shifter cheaper.
				rs2_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd1: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs1_nxt = mem_rdata & {32{|cir_rs2}};
			end
			3'd3: begin
				mem_addr = address_adder;
				mem_wen = 4'hf; // TODO byte/halfword?
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_JAL: case (state)
			3'd0: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs1_nxt = pc;
				rs2_nxt = 32'd4;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_JALR: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
			end
			3'd1: begin
				// Note the rs2 register is used to match load/store.
				rs2_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd2: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
				rs1_nxt = pc;
				rs2_nxt = 32'd4;				
			end
			3'd3: begin
				mem_addr = reg_addr(cir_rd);
				mem_wen = 4'hf & {4{|cir_rd}};
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		RV_OPC_BRANCH: case (state)
			3'd0: begin
				mem_addr = reg_addr(cir_rs1);
				mem_ren = |cir_rs1;
			end
			3'd1: begin
				mem_addr = reg_addr(cir_rs2);
				mem_ren = |cir_rs2;
				rs1_nxt = mem_rdata & {32{|cir_rs1}};
			end
			3'd2: begin
				rs2_nxt = mem_rdata & {32{|cir_rs2}};
			end
			3'd3: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
			end
			3'd4: begin
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

		// Unknown -> NOP
		default: case (state)
			3'd0: begin
				mem_addr = address_adder;
				mem_ren = 1'b1;
				pc_nxt = address_adder;
			end
			3'd1: begin
				cir_nxt = mem_rdata;
				state_nxt = 3'h0;
			end
		endcase

	endcase
end

always @ (posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		pc <= RESET_VECTOR;
		cir <= {20'h0, 5'h0, RV_OPC_JAL};
		rs1 <= 32'd0;
		rs2 <= 32'd0;
		state <= 3'd7;
	end else if (!mem_stall) begin
		pc <= pc_nxt;
		cir <= cir_nxt;
		rs1 <= rs1_nxt;
		rs2 <= rs2_nxt;
		state <= state_nxt;
	end
end

// ----------------------------------------------------------------------------

wire alu_cmp;
assign branch_true = alu_cmp != cir_funct3[0];

wire alu_just_add =
	cir_opc == RV_OPC_LUI ||
	cir_opc == RV_OPC_AUIPC ||
	cir_opc == RV_OPC_JAL ||
	cir_opc == RV_OPC_JALR;

hazard1_alu alu (
	.rs1                (rs1),
	.rs2                (rs2),

	.funct3             (cir_funct3),
	.instr_is_branch    (cir_opc[6]),
	.instr_is_loadstore (cir_opc[6] && !cir_opc[4]),
	.instr_is_rtype     (cir_opc[6:4] == 3'b011),
	.just_add           (alu_just_add),

	.sub_or_arith_shift (cir_funct7[5]),
	.result             (mem_wdata),
	.cmp                (alu_cmp)
);

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
