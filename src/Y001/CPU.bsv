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

`define ENABLE_SPEW

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
    FETCH,
    DECODE,
    EXECUTE,
    MEMORY_ACCESS,
    WRITEBACK
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

    // General purpose register (GPR) file
    GPRFile              gprFile <- mkGPRFile;

    // Constrol and status register (CSR) file
    CSRFile              csrFile <- mkCSRFile;

    // Stages (unpipelined)
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

        state <= FETCH;
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

    method Action step;
        Bit#(1) epoch = 0; // Hardcoded in non-pipelined implementation

        //
        // Dump state
        //
        $display("> STATE   : ", fshow(state));
        if (state != FETCH) begin
            $display("> Fetch   : ** IDLE **");
        end else begin
            $display("> Fetch   : Requesting $%0x", pc);
        end

        if (if_id.common.isBubble) begin
            $display("> Decode  : ** IDLE ** ");
        end else begin
            if (if_id.epoch != epoch) begin
                $display("> Decode  : *STALE* ", fshow(if_id));
            end else begin
                $display("> Decode  :  ", fshow(if_id));
            end
        end

        if (id_ex.common.isBubble) begin
            $display("> Execute : ** IDLE **");
        end else begin
            if (id_ex.epoch != epoch) begin
                $display("> Execute : *STALE* ", fshow(id_ex));
            end else begin
                $display("> Execute :  ", fshow(id_ex));
            end
        end

        if (ex_mem.common.isBubble) begin
            $display("> Memory  : ** IDLE **");
        end else begin
            $display("> Memory  : ", fshow(ex_mem));
        end

        if (mem_wb.common.isBubble) begin
            $display("> WriteB  : ** IDLE **");
        end else begin
            $display("> WriteB  : ", fshow(mem_wb));
        end

        //
        // Process the current cycle
        //
        IF_ID if_id_ = defaultValue;
        ID_EX id_ex_ = defaultValue;
        EX_MEM ex_mem_ = defaultValue;
        MEM_WB mem_wb_ = defaultValue;
        WB_OUT wb_out_ = defaultValue;

        case (state)
            FETCH: begin
                if_id_  <- fetchStage.fetch(pc, ex_mem, epoch);
                if (if_id_ != defaultValue) begin
                    if_id <= if_id_;
                    state <= DECODE;
                end
            end

            DECODE: begin
                id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);
                if (id_ex_ != defaultValue) begin
                    id_ex <= id_ex_;
                    state <= EXECUTE;

                    if_id <= defaultValue;
                end
            end

            EXECUTE: begin
                ex_mem_ <- executeStage.execute(id_ex, 
                    tagged Invalid, // RS1 forward (not used on unpipelined CPUs) 
                    tagged Invalid, // RS2 forward (not used on unpipelined CPUs)
                    id_ex.epoch,    // Simple set the epoch to that contained in id_ex (epochs not implemented on unpipelined CPUs)
                    csrFile.trapController, 
                    csrFile.csrWritePermission);
                if (ex_mem_ != defaultValue) begin
                    ex_mem <= ex_mem_;
                    state <= MEMORY_ACCESS;

                    id_ex <= defaultValue;

                    pc <= (ex_mem_.cond ? ex_mem_.aluOutput : pc + 4);
                end
            end

            MEMORY_ACCESS: begin
                mem_wb_ <- memoryStage.accessMemory(ex_mem);
                if (mem_wb_ != defaultValue) begin
                    mem_wb <= mem_wb_;
                    state <= WRITEBACK;

                    ex_mem <= defaultValue;
                end
            end

            WRITEBACK: begin
                wb_out_ <- writebackStage.writeback(mem_wb, gprFile.gprWritePort, csrFile.csrWritePort);
                csrFile.incrementInstructionsRetiredCounter;

                retiredInstruction.wset(RetiredInstruction {
                    programCounter: wb_out_.common.pc,
                    instruction:    wb_out_.common.ir
                });

                wb_out <= wb_out_;
                state <= FETCH;

                mem_wb <= defaultValue;
            end
        endcase

        //
        // Increment cycle counters
        //
        csrFile.incrementCycleCounters;
    endmethod
endmodule
