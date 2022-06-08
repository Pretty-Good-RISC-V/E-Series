import PGRV::*;
import PipelineRegisters::*;
import GPRFile::*;

interface DecodeStage;
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
endinterface

module mkDecodeStage(DecodeStage);
    method ActionValue#(ID_EX) decode(IF_ID if_id, GPRReadPort gprReadPort1, GPRReadPort gprReadPort2);
        let func7  = if_id.common.instruction[31:25];
        let rs2    = if_id.common.instruction[24:20];
        let rs1    = if_id.common.instruction[19:15];
        let func3  = if_id.common.instruction[14:12];
        let rd     = if_id.common.instruction[11:7];
        let opcode = if_id.common.instruction[6:0];
        let a      = gprReadPort1.read(rs1);
        let b      = gprReadPort2.read(rs2);

        Word immediate = case(opcode) matches
            // LUI/AUIPC
            'b0?10111: begin
                return signExtend(if_id.common.instruction[31:12]);
            end

            // JAL/JALR
            // 'b110?111: begin
            //     if (opcode[3]) begin
            //         // JAL
            //         return {};
            //     end else begin
            //         // JALR
            //         return if_id.common.instruction[31:12];
            //     end
            // end

            // Branches
            'b1100011: begin
                return signExtend({func7[6], rd[0], func7[5:0], rd[4:1], 1'b0});
            end

            default: begin
                return 0;
            end
            // 
        endcase;

        return ID_EX {
            common: if_id.common,
            nextProgramCounter: if_id.nextProgramCounter,
            a: a,
            b: b,
            immediate: signExtend(immediate)
        };
    endmethod
endmodule
