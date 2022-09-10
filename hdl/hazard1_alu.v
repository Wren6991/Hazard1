/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

`default_nettype none

module hazard1_alu (
	input  wire [31:0] rs1,
	input  wire [31:0] rs2,

	input  wire [2:0]  funct3,              // instr[14:12]
	input  wire        instr_is_branch,     // instr[6]
	input  wire        instr_is_rtype,      // instr[6:4] == 3'b011
	input  wire        sub_or_arith_shift,  // instr[30]
	input  wire        just_add,

	output reg  [31:0] result,
	output wire        cmp
);

`include "rv_opcodes.vh"

wire sub = !just_add && (instr_is_branch || (instr_is_rtype && sub_or_arith_shift));

// TODO this is not ideal on iCE40, creates an additional LUT layer that we
// could have absorbed a mux into.
wire [31:0] op1 = rs1;
wire [31:0] op2 = rs2 ^ {32{sub}};

wire [31:0] sum = op1 + op2 + sub;

wire cmp_is_unsigned = funct3[1] && (funct3[2] || funct3[0]);

wire lt = op1[31] == op2[31] ? sum[31] :
          cmp_is_unsigned    ? op2[31] : op1[31];

assign cmp = instr_is_branch && !funct3[2] ? rs1 == rs2 : lt;


wire [31:0] shift_dout;
wire shift_right_nleft = funct3[2];

hazard1_shift_barrel shifter (
	.din         (rs1),
	.shamt       (op2[4:0]),
	.right_nleft (shift_right_nleft),
	.arith       (sub_or_arith_shift),
	.dout        (shift_dout)
);

reg [31:0] bitwise;
always @ (*) begin
	case (funct3[1:0])
	RV_FUNCT3_AND[1:0]: bitwise = op1 & op2;
	RV_FUNCT3_OR [1:0]: bitwise = op1 | op2;
	RV_FUNCT3_XOR[1:0]: bitwise = op1 ^ op2;
	default:            bitwise =       op2;
	endcase
end

always @ (*) begin
	casez ({funct3})
	RV_FUNCT3_ADD:  result = sum;
	RV_FUNCT3_SLL:  result = shift_dout;
	RV_FUNCT3_SLT:  result = {31'd0, cmp};
	RV_FUNCT3_SLTU: result = {31'd0, cmp};
	RV_FUNCT3_XOR:  result = bitwise;
	RV_FUNCT3_SRL:  result = shift_dout;
	RV_FUNCT3_OR:   result = bitwise;
	RV_FUNCT3_AND:  result = bitwise;
	endcase
	if (just_add) begin
		result = sum;
	end
end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
