import PGRV::*;
import GPRFile::*;
import PipelineRegisters::*;

interface WritebackStage;
    method Action writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
endinterface

module mkWritebackStage(WritebackStage);
    method Action writeback(MEM_WB mem_wb, GPRWritePort gprWritePort);
    endmethod
endmodule
