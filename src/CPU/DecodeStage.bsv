import PGRV::*;
import PipelineRegisters::*;
import GPRFile::*;

interface DecodeStage;
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
endinterface

module mkDecodeStage(DecodeStage);
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
        // Instruction field extraction
        let rs2    = if_id.common.instruction[24:20];
        let rs1    = if_id.common.instruction[19:15];
        let opcode = if_id.common.instruction[6:0];

        // Determine immediate value stored in the instruction
        Word immediate = case(opcode) matches
            // S-Type
            'b0100011: begin
                return signExtend({
                    if_id.common.instruction[31:25],
                    if_id.common.instruction[11:7]
                });
            end

            // B-Type
            'b1100011: begin
                return signExtend({
                    if_id.common.instruction[31],
                    if_id.common.instruction[7],
                    if_id.common.instruction[30:25],
                    if_id.common.instruction[11:8],
                    1'b0
                });
            end

            // U-Type
            'b0?10111: begin
                return {if_id.common.instruction[31:12], 12'b0};
            end

            // J-Type
            'b1101111: begin
                return signExtend({
                    if_id.common.instruction[31],
                    if_id.common.instruction[19:12],
                    if_id.common.instruction[20],
                    if_id.common.instruction[30:21],
                    1'b0
                });
            end

            // (default) assume I-Type (won't be used otherwise)
            default: begin
                return signExtend(if_id.common.instruction[31:12]);
            end
        endcase;

        // Read GPR registers
        let a = gprReadPort1.read(rs1);
        let b = gprReadPort2.read(rs2);

        return ID_EX {
            common: if_id.common,
            nextProgramCounter: if_id.nextProgramCounter,
            a: a,
            b: b,
            immediate: immediate
        };
    endmethod
endmodule
