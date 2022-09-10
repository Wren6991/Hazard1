/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

// Implement the three shifts (left logical, right logical, right arithmetic)

`default_nettype none

module hazard1_shift_barrel (
	input wire [31:0] din,
	input wire [4:0]  shamt,
	input wire        right_nleft,
	input wire        rotate,
	input wire        arith,
	output reg [31:0] dout
);

reg [31:0] din_rev;
reg [31:0] shift_accum;
reg              sext;

always @ (*) begin: shift
	integer i;

	for (i = 0; i < 32; i = i + 1)
		din_rev[i] = right_nleft ? din[32 - 1 - i] : din[i];

	sext = arith && din_rev[0];

	shift_accum = din_rev;
	for (i = 0; i < 5; i = i + 1) begin
		if (shamt[i]) begin
			shift_accum = (shift_accum << (1 << i)) | ({32{sext}} & ~({32{1'b1}} << (1 << i)));
		end
	end

	for (i = 0; i < 32; i = i + 1)
		dout[i] = right_nleft ? shift_accum[32 - 1 - i] : shift_accum[i];
end

endmodule

`ifndef YOSYS
`default_nettype wire
`endif
