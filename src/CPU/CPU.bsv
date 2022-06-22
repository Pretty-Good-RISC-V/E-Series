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
    // CPU cycle counter
    Reg#(Word)           cycle  <- mkReg(0);

    // Pipeline registers
    Reg#(ProgramCounter) pc     <- mkReg(initialProgramCounter);
    Reg#(IF_ID)          if_id  <- mkReg(defaultValue);
    Reg#(ID_EX)          id_ex  <- mkReg(defaultValue);
    Reg#(EX_MEM)         ex_mem <- mkReg(defaultValue);
    Reg#(MEM_WB)         mem_wb <- mkReg(defaultValue);

    // Pipeline epoch
    Reg#(Bit#(1))        epoch  <- mkReg(0);

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

    function Bool detectLoadHazard(IF_ID if_id_, ID_EX id_ex_);
        Bool loadHazard = False;
        if (id_ex_.common.ir[6:0] == 'b0000011 &&
           (id_ex_.common.ir[11:7] == if_id.common.ir[19:15])) begin
                loadHazard = True;
        end
        return loadHazard;
    endfunction

    rule pipeline;
        //
        // Forward declarations of intermediate pipeline structures
        //
        ProgramCounter         pc_;
        IF_ID                  if_id_;
        ID_EX                  id_ex_;
        EX_MEM                 ex_mem_;
        MEM_WB                 mem_wb_;
        PipelineRegisterCommon wb_out_;

        //
        // Process the pipeline
        //
        $display("-----------------------------");
        $display("Cycle   : %0d", cycle);

        id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2);
        ex_mem_ <- executeStage.execute(id_ex, epoch, toPut(asIfc(epoch)));

        if_id_  <- fetchStage.fetch(pc, ex_mem_, epoch);

        mem_wb_ <- memoryStage.memory(ex_mem);
        wb_out_ <- writebackStage.writeback(mem_wb, gprFile.gprWritePort);

        if(if_id.common.isBubble) begin
            $display("Fetch   : Stalled fetching $%0x", pc);
        end else begin
            $display("Fetch   : $%0x", pc);
        end

        if (if_id.common.isBubble) begin
            $display("Decode  : ** BUBBLE ** ");
        end else begin
            $display("Decode  : ", fshow(if_id));
        end

        if (id_ex.common.isBubble) begin
            $display("Execute : ** BUBBLE **");
        end else begin
            $display("Execute : ", fshow(id_ex));
        end

        if (ex_mem.common.isBubble) begin
            $display("Memory  : ** BUBBLE **");
        end else begin
            $display("Memory  : ", fshow(ex_mem));
        end

        if (mem_wb.common.isBubble) begin
            $display("WriteB  : ** BUBBLE **");
        end else begin
            $display("WriteB  : ", fshow(mem_wb));
        end

        //
        // Check for traps (and update the program counter to the trap handler if one exists)
        //
        if (wb_out_.trap matches tagged Valid .trap) begin
            pc_ <- csrFile.trapController.beginTrap(trap);
            $display("TRAP DETECTED: Jumping to $%0x", pc_);
            epoch <= ~epoch;
        end else begin
            pc_ = if_id_.npc;
        end

        //
        // If any stage is stalled, all staged *before* that are
        // also stalled
        //
        if (memoryStage.isStalled) begin
            $display("Memory Stage Stalled");
            mem_wb <= mem_wb;
        end else if(detectLoadHazard(if_id_, id_ex_)) begin
            $display("Load Hazard");
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
        end else if(if_id_.common.isBubble) begin
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
        end else begin
            $display("No stalls");
            pc     <= pc_;
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
        end

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
                programCounter: wb_out_.pc,
                instruction:    wb_out_.ir
            });
        end

        cycle <= cycle + 1;
    endrule

    interface ReadOnlyMemoryClient  instructionMemoryClient = fetchStage.instructionMemoryClient;
    interface ReadWriteMemoryClient dataMemoryClient        = memoryStage.dataMemoryClient;

    interface Get getRetiredInstruction;
        method ActionValue#(Maybe#(RetiredInstruction)) get;
            return retiredInstruction.wget;
        endmethod
    endinterface
endmodule
