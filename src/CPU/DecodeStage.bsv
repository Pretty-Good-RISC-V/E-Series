import PGRV::*;
import PipelineRegisters::*;
import GPRFile::*;

interface DecodeStage;
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2, Maybe#(Word) rs1Forward, Maybe#(Word) rs2Forward);
endinterface

module mkDecodeStage(DecodeStage);
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2, Maybe#(Word) rs1Forward, Maybe#(Word) rs2Forward);
        // Instruction field extraction
        let rs2    = if_id.common.ir[24:20];
        let rs1    = if_id.common.ir[19:15];
        let opcode = if_id.common.ir[6:0];

        // Determine immediate value stored in the instruction
        Word imm = case(opcode) matches
            // S-Type
            'b0100011: begin
                return signExtend({
                    if_id.common.ir[31:25],
                    if_id.common.ir[11:7]
                });
            end

            // B-Type
            'b1100011: begin
                return signExtend({
                    if_id.common.ir[31],
                    if_id.common.ir[7],
                    if_id.common.ir[30:25],
                    if_id.common.ir[11:8],
                    1'b0
                });
            end

            // U-Type
            'b0?10111: begin
                return signExtend({
                    if_id.common.ir[31:12], 
                    12'b0
                });
            end

            // J-Type
            'b1101111: begin
                return signExtend({
                    if_id.common.ir[31],
                    if_id.common.ir[19:12],
                    if_id.common.ir[20],
                    if_id.common.ir[30:21],
                    1'b0
                });
            end

            // (default) assume I-Type (won't be used otherwise)
            default: begin
                return signExtend(if_id.common.ir[31:20]);
            end
        endcase;

        // Read GPR registers
        let gpr1 = gprReadPort1.read(rs1);
        let gpr2 = gprReadPort2.read(rs2);
        // $display("Decode - RS1: x%0d = $%0x", rs1, gpr1);
        // $display("Decode - RS2: x%0d = $%0x", rs2, gpr2);

        let a = fromMaybe(gpr1, rs1Forward);
        let b = fromMaybe(gpr2, rs2Forward);

        // $display("Decode - RS1: x%0d = $%0x", rs1, a);
        // $display("Decode - RS2: x%0d = $%0x", rs2, b);

        return ID_EX {
            common: if_id.common,
            epoch:  if_id.epoch,
            npc:    if_id.npc,
            a:      a,
            b:      b,
            imm:    imm
        };
    endmethod
endmodule
