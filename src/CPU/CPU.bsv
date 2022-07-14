import PGRV::*;

import BranchPrediction::*;
import CSRFile::*;
import DecodeStage::*;
import ExecuteStage::*;
import FetchStage::*;
import GPRFile::*;
import ISAUtils::*;
import MemoryIO::*;
import MemoryStage::*;
import PipelineRegisters::*;
import PipelineUtils::*;
import WritebackStage::*;

import ClientServer::*;
import GetPut::*;
import StmtFSM::*;

`undef ENABLE_SPEW

typedef struct {
    ProgramCounter pc;
    IF_ID  if_id;
    ID_EX  id_ex;
    EX_MEM ex_mem;
    MEM_WB mem_wb;
    WB_OUT wb_out;
} PipelineState deriving(Bits, Eq, FShow);

typedef struct {
    ProgramCounter programCounter;
    Word32 instruction;
} RetiredInstruction deriving(Bits, Eq, FShow);

typedef enum {
    RESET,
    INITIALIZING,
    READY
} CPUState deriving(Bits, Eq, FShow);

interface CPU;
    method Action   step; 
    method CPUState getState;

    interface ReadOnlyMemoryClient#(XLEN, 32)    instructionMemoryClient;
    interface ReadWriteMemoryClient#(XLEN, XLEN) dataMemoryClient;

    interface Get#(Maybe#(RetiredInstruction))   getRetiredInstruction;
    interface Get#(PipelineState)                getPipelineState;
endinterface

module mkCPU#(
    ProgramCounter initialProgramCounter
)(CPU);
    Reg#(CPUState)       state  <- mkReg(RESET);

    BranchPredictor      bp     <- mkSimpleBranchPredictor;

    // Pipeline registers
    Reg#(ProgramCounter) pc     <- mkReg(initialProgramCounter);
    Reg#(IF_ID)          if_id  <- mkReg(defaultValue);
    Reg#(ID_EX)          id_ex  <- mkReg(defaultValue);
    Reg#(EX_MEM)         ex_mem <- mkReg(defaultValue);
    Reg#(MEM_WB)         mem_wb <- mkReg(defaultValue);
    Reg#(WB_OUT)         wb_out <- mkReg(defaultValue);

    // Pipeline epoch
    Reg#(Bit#(1))        epoch  <- mkReg(0);

    // General purpose register (GPR) file
    GPRFile              gprFile <- mkGPRFile;

    // Constrol and status register (CSR) file
    CSRFile              csrFile <- mkCSRFile;

    // Pipeline stages
    FetchStage           fetchStage     <- mkFetchStage(bp);  // Stage 1
    DecodeStage          decodeStage    <- mkDecodeStage;     // Stage 2
    ExecuteStage         executeStage   <- mkExecuteStage;    // Stage 3
    MemoryStage          memoryStage    <- mkMemoryStage;     // Stage 4
    WritebackStage       writebackStage <- mkWritebackStage;  // Stage 5

    // Retired instruction this cycle if any
    RWire#(RetiredInstruction) retiredInstruction <- mkRWire;

    //
    // Initialization
    //
    Reg#(Bit#(10)) gprInitIndex <- mkRegU;
    Stmt initializationStatements = (seq
        //
        // Zero the GPRs
        //
        for (gprInitIndex <= 0; gprInitIndex <= 32; gprInitIndex <= gprInitIndex + 1)
            gprFile.gprWritePort.write(truncate(gprInitIndex), 0);

        state <= READY;
    endseq);

    FSM initializationMachine <- mkFSMWithPred(initializationStatements, state == INITIALIZING);

    rule initialization(state == RESET);
        state <= INITIALIZING;
        initializationMachine.start;
    endrule

    interface ReadOnlyMemoryClient  instructionMemoryClient = fetchStage.instructionMemoryClient;
    interface ReadWriteMemoryClient dataMemoryClient        = memoryStage.dataMemoryClient;

    interface Get getRetiredInstruction;
        method ActionValue#(Maybe#(RetiredInstruction)) get;
            return retiredInstruction.wget;
        endmethod
    endinterface

    interface Get getPipelineState;
        method ActionValue#(PipelineState) get;
            return PipelineState {
                pc: pc,
                if_id: if_id,
                id_ex: id_ex,
                ex_mem: ex_mem,
                mem_wb: mem_wb,
                wb_out: wb_out
            };
        endmethod
    endinterface

    method CPUState getState;
        return state;
    endmethod

    method Action step if(state == READY);
        //
        // Forward declarations of intermediate pipeline structures
        //
        ProgramCounter  pc_;
        IF_ID           if_id_;
        ID_EX           id_ex_;
        EX_MEM          ex_mem_;
        MEM_WB          mem_wb_;
        WB_OUT          wb_out_;

        //
        // Determine forwarded operands
        //
        match { .rs1Forward, .rs2Forward } = getForwardedOperands(id_ex, ex_mem, mem_wb, wb_out);

        //
        // Process the pipeline
        //

        // First, run the execute stage since we need to feed its result
        // to the decode stage this cycle
        ex_mem_ <- executeStage.execute(id_ex, rs1Forward, rs2Forward, epoch, csrFile.csrWritePermission);

        let flipEpoch = False;
        if (ex_mem_.cond && id_ex.npc != ex_mem_.aluOutput) begin
`ifdef ENABLE_SPEW
            $display("Branch not as prediced...updating epoch");
`endif
            flipEpoch = True;
        end

        if_id_  <- fetchStage.fetch(pc, ex_mem_, epoch);
        id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

        // NOTE: execute stage was executed above

        mem_wb_ <- memoryStage.accessMemory(ex_mem);
        wb_out_ <- writebackStage.writeback(mem_wb, gprFile.gprWritePort, csrFile.csrWritePort);

        if(if_id.common.isBubble) begin
            $display("Fetch   : Waiting for $%0x", pc);
        end else begin
            $display("Fetch   : Requesting $%0x", pc);
        end

        if (if_id.common.isBubble) begin
            $display("Decode  : ** BUBBLE ** ");
        end else begin
            $display("Decode  : ", fshow(if_id));
        end

        if (id_ex.common.isBubble) begin
            $display("Execute : ** BUBBLE **");
        end else begin
            if (id_ex.epoch != epoch) begin
                $display("Execute : *STALE* ", fshow(id_ex));
            end else begin
                $display("Execute : ", fshow(id_ex));
            end
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
        if (wb_out_.common.trap matches tagged Valid .trap) begin
            pc_ <- csrFile.trapController.beginTrap(trap);
            $display("TRAP DETECTED: Jumping to $%0x", pc_);
            flipEpoch = True;
        end else begin
            pc_ = (ex_mem_.cond ? ex_mem_.aluOutput : if_id_.npc);
        end

        if (flipEpoch) begin
            epoch <= ~epoch;
        end

        //
        // If any stage is stalled, all stages *before* that are
        // also stalled
        //
        if (memoryStage.isStalled) begin
`ifdef ENABLE_SPEW
            $display("Memory Stage Stalled");
`endif
            mem_wb <= mem_wb;
        end else if(detectLoadHazard(if_id_, id_ex_)) begin
`ifdef ENABLE_SPEW
            $display("Load Hazard - inserting bubble into EX");
`endif
            id_ex  <= defaultValue; // Don't issue an instruction - insert bubble
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
            wb_out <= wb_out_;
        end else if(if_id_.common.isBubble) begin
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
            wb_out <= wb_out_;
        end else begin
            pc     <= pc_;
            if_id  <= if_id_;
            id_ex  <= id_ex_;
            ex_mem <= ex_mem_;
            mem_wb <= mem_wb_;
            wb_out <= wb_out_;
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
        if (!wb_out_.common.isBubble) begin
            csrFile.incrementInstructionsRetiredCounter;

            retiredInstruction.wset(RetiredInstruction {
                programCounter: wb_out_.common.pc,
                instruction:    wb_out_.common.ir
            });
        end
    endmethod
endmodule
