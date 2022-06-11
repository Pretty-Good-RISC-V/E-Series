import PGRV::*;
import CSRFile::*;
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

typedef struct {
    ProgramCounter programCounter;
    Word32 instruction;
} RetiredInstruction deriving(Bits, Eq, FShow);

interface CPU;
    interface ReadOnlyMemoryClient#(XLEN, 32)    instructionMemoryClient;
    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;

    interface Get#(Maybe#(RetiredInstruction))   getRetiredInstruction;
endinterface

module mkCPU#(
    ProgramCounter initialProgramCounter
)(CPU);
    // Pipeline Registers
    Reg#(ProgramCounter) pc     <- mkReg(initialProgramCounter);
    Reg#(ProgramCounter) nextPC <- mkRegU;
    Reg#(IF_ID)          if_id  <- mkReg(defaultValue);
    Reg#(ID_EX)          id_ex  <- mkReg(defaultValue);
    Reg#(EX_MEM)         ex_mem <- mkReg(defaultValue);
    Reg#(MEM_WB)         mem_wb <- mkReg(defaultValue);

    // General purpose register (GPR) file
    GPRFile gprFile <- mkGPRFile;

    // Constrol and status register (CSR) file
    CSRFile csrFile <- mkCSRFile;

    // Pipeline stages
    FetchStage     fetchStage     <- mkFetchStage;      // Stage 1
    DecodeStage    decodeStage    <- mkDecodeStage;     // Stage 2
    ExecuteStage   executeStage   <- mkExecuteStage;    // Stage 3
    MemoryStage    memoryStage    <- mkMemoryStage;     // Stage 4
    WritebackStage writebackStage <- mkWritebackStage;  // Stage 5

    // Retired instruction this cycle if any
    RWire#(RetiredInstruction) retiredInstruction <- mkRWire;

    rule pipeline;
        //
        // Process the pipeline
        //
        let if_id_  <- fetchStage.fetch(pc, ex_mem, toPut(asIfc(nextPC)));
        let id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2);
        let ex_mem_ <- executeStage.execute(id_ex);
        let mem_wb_ <- memoryStage.memory(ex_mem);
        let wb_out_ <- writebackStage.writeback(mem_wb, gprFile.gprWritePort);

        let stalled = fetchStage.isStalled || memoryStage.isStalled;
        if (!stalled) begin
            //
            // Update the pipeline registers
            //
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;

            //
            // Check for traps (and update the program counter if one exists)
            //
            let updatedPC = nextPC;
            if (wb_out_.trap matches tagged Valid .trap) begin
                updatedPC <- csrFile.trapController.beginTrap(trap);
            end

            //
            // Update the program counter
            //
            pc <= updatedPC;

            //
            // Increment cycle counters
            //
            csrFile.incrementCycleCounters;

            //
            // Increment retirement counter and inform any clients 
            // of the retired instruction (this is assuming the
            // instruction wasn't a pipeline bubble)
            //
            if (!wb_out_.isBubble) begin
                csrFile.incrementInstructionsRetiredCounter;

                retiredInstruction.wset(RetiredInstruction {
                    programCounter: wb_out_.programCounter,
                    instruction:    wb_out_.instruction
                });
            end
        end
    endrule

    interface ReadOnlyMemoryClient  instructionMemoryClient = fetchStage.instructionMemoryClient;
    interface ReadWriteMemoryClient dataMemoryClient        = memoryStage.dataMemoryClient;

    interface Get getRetiredInstruction;
        method ActionValue#(Maybe#(RetiredInstruction)) get;
            return retiredInstruction.wget;
        endmethod
    endinterface
endmodule
