import PGRV::*;
import GPRFile::*;
import PipelineRegisters::*;

interface WritebackStage;
    method ActionValue#(PipelineRegisterCommon) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
endinterface

module mkWritebackStage(WritebackStage);
    method ActionValue#(PipelineRegisterCommon) writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
        let opcode = mem_wb.common.ir[6:0];
        let rd_    = mem_wb.common.ir[11:7];

        match { .rd, .value } = case (opcode) matches
            'b0000011: begin    // LOAD
                return tuple2(rd_, mem_wb.lmd);
            end
            'b0?10011: begin    // ALU
                return tuple2(rd_, mem_wb.lmd);
            end
            'b1100111: begin    // JALR
                return tuple2(rd_, mem_wb.aluOutput);
            end
            default: begin
                return tuple2(0, 0);
            end
        endcase;

        gprWritePort.write(rd, value);

        return mem_wb.common;
    endmethod
endmodule
