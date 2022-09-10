/*****************************************************************************\
|                        Copyright (C) 2022 Luke Wren                         |
|                     SPDX-License-Identifier: Apache-2.0                     |
\*****************************************************************************/

`ifndef _HAZARD1_RV_OPCODES_VH
`define _HAZARD1_RV_OPCODES_VH

// Instruction layout

localparam RV_OPC_LSB     = 0;
localparam RV_OPC_BITS    = 7;

localparam RV_RD_LSB      = 7;
localparam RV_RD_BITS     = 5;

localparam RV_FUNCT3_LSB  = 12;
localparam RV_FUNCT3_BITS = 3;

localparam RV_RS1_LSB     = 15;
localparam RV_RS1_BITS    = 5;

localparam RV_RS2_LSB     = 20;
localparam RV_RS2_BITS    = 5;

localparam RV_FUNCT7_LSB  = 25;
localparam RV_FUNCT7_BITS = 7;

// Major opcodes

localparam [6:0] RV_OPC_BRANCH  = 7'b1100011
localparam [6:0] RV_OPC_JALR    = 7'b1100111
localparam [6:0] RV_OPC_JAL     = 7'b1101111
localparam [6:0] RV_OPC_LUI     = 7'b0110111
localparam [6:0] RV_OPC_AUIPC   = 7'b0010111
localparam [6:0] RV_OPC_OP_IMM  = 7'b0010011
localparam [6:0] RV_OPC_OP      = 7'b0110011
localparam [6:0] RV_OPC_LOAD    = 7'b0000011
localparam [6:0] RV_OPC_STORE   = 7'b0100011
localparam [6:0] RV_OPC_SYSTEM  = 7'b1110011

// Arithmetic functions

localparam [2:0] RV_FUNCT3_ADD  =  3'b000;
localparam [2:0] RV_FUNCT3_SUB  =  3'b000;
localparam [2:0] RV_FUNCT3_SLL  =  3'b001;
localparam [2:0] RV_FUNCT3_SLT  =  3'b010;
localparam [2:0] RV_FUNCT3_SLTU =  3'b011;
localparam [2:0] RV_FUNCT3_XOR  =  3'b100;
localparam [2:0] RV_FUNCT3_SRL  =  3'b101;
localparam [2:0] RV_FUNCT3_SRA  =  3'b101;
localparam [2:0] RV_FUNCT3_OR   =  3'b110;
localparam [2:0] RV_FUNCT3_AND  =  3'b111;

localparam [6:0] RV_FUNCT7_ADD  =  7'b0000000;
localparam [6:0] RV_FUNCT7_SUB  =  7'b0100000;
localparam [6:0] RV_FUNCT7_SLL  =  7'b0000000;
localparam [6:0] RV_FUNCT7_SLT  =  7'b0000000;
localparam [6:0] RV_FUNCT7_SLTU =  7'b0000000;
localparam [6:0] RV_FUNCT7_XOR  =  7'b0000000;
localparam [6:0] RV_FUNCT7_SRL  =  7'b0000000;
localparam [6:0] RV_FUNCT7_SRA  =  7'b0100000;
localparam [6:0] RV_FUNCT7_OR   =  7'b0000000;
localparam [6:0] RV_FUNCT7_AND  =  7'b0000000;

// Load/store functions

localparam [2:0] RV_FUNCT3_LB   = 3'b000;
localparam [2:0] RV_FUNCT3_LH   = 3'b001;
localparam [2:0] RV_FUNCT3_LW   = 3'b010;
localparam [2:0] RV_FUNCT3_LBU  = 3'b100;
localparam [2:0] RV_FUNCT3_LHU  = 3'b101;

localparam [2:0] RV_FUNCT3_SB   = 3'b000;
localparam [2:0] RV_FUNCT3_SH   = 3'b001;
localparam [2:0] RV_FUNCT3_SW   = 3'b010;

// Branch functions

localparam [2:0] RV_FUNCT3_BEQ  = 3'b000;
localparam [2:0] RV_FUNCT3_BNE  = 3'b001;
localparam [2:0] RV_FUNCT3_BLT  = 3'b100;
localparam [2:0] RV_FUNCT3_BGE  = 3'b101;
localparam [2:0] RV_FUNCT3_BLTU = 3'b110;
localparam [2:0] RV_FUNCT3_BGEU = 3'b111;

`endif
