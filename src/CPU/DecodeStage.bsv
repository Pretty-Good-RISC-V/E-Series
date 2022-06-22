import PGRV::*;
import PipelineRegisters::*;
import GPRFile::*;

interface DecodeStage;
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
endinterface

module mkDecodeStage(DecodeStage);
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
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
                return signExtend(if_id.common.ir[31:12]);
            end
        endcase;

        // Read GPR registers
        let a = gprReadPort1.read(rs1);
        let b = gprReadPort2.read(rs2);

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
