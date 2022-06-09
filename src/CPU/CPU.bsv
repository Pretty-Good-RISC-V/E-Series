import PGRV::*;
import DecodeStage::*;
import ExecuteStage::*;
import FetchStage::*;
import GPRFile::*;
import MemoryIO::*;
import MemoryStage::*;
import PipelineRegisters::*;
import WritebackStage::*;

import ClientServer::*;
import GetPut::*;

interface CPU;
    interface ReadOnlyMemoryClient#(XLEN, 32)    instructionMemoryClient;
    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;
endinterface

module mkCPU(CPU);
    // Pipeline Registers
    Reg#(Word)   pc     <- mkReg('h8000_0000);
    Reg#(Word)   nextPC <- mkRegU;
    Reg#(IF_ID)  if_id  <- mkReg(defaultValue);
    Reg#(ID_EX)  id_ex  <- mkReg(defaultValue);
    Reg#(EX_MEM) ex_mem <- mkReg(defaultValue);
    Reg#(MEM_WB) mem_wb <- mkReg(defaultValue);

    // General purpose register file
    GPRFile gprFile <- mkGPRFile;

    // Pipeline stages
    FetchStage     fetchStage     <- mkFetchStage;      // Stage 1
    DecodeStage    decodeStage    <- mkDecodeStage;     // Stage 2
    ExecuteStage   executeStage   <- mkExecuteStage;    // Stage 3
    MemoryStage    memoryStage    <- mkMemoryStage;     // Stage 4
    WritebackStage writebackStage <- mkWritebackStage;  // Stage 5


    rule pipeline;
        let if_id_  <- fetchStage.fetch(pc, ex_mem, toPut(asIfc(nextPC)));
        let id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2);
        let ex_mem_ <- executeStage.execute(id_ex);
        let mem_wb_ <- memoryStage.memory(ex_mem);
        writebackStage.writeback(mem_wb, gprFile.gprWritePort);

        let stalled = fetchStage.isStalled || memoryStage.isStalled;
        if (!stalled) begin
            pc     <= nextPC;
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
        end
    endrule

    interface ReadOnlyMemoryClient  instructionMemoryClient = fetchStage.instructionMemoryClient;
    interface ReadWriteMemoryClient dataMemoryClient        = memoryStage.dataMemoryClient;
endmodule
