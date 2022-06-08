import PGRV::*;
import MemoryIO::*;
import PipelineRegisters::*;

import ClientServer::*;
import GetPut::*;
import Memory::*;

interface MemoryStage;
    method ActionValue#(MEM_WB) memory(EX_MEM ex_mem);

    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;
endinterface

module mkMemoryStage(MemoryStage);
    RWire#(MemoryRequest#(XLEN, XLEN))    dataMemoryRequest  <- mkRWire;
    RWire#(FallibleMemoryResponse#(XLEN)) dataMemoryResponse <- mkRWire;

    method ActionValue#(MEM_WB) memory(EX_MEM ex_mem);
        return defaultValue;
    endmethod

    interface ReadWriteMemoryClient dataMemoryClient = toGPClient(dataMemoryRequest, dataMemoryResponse);
endmodule
