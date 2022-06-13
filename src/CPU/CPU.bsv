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
    Reg#(Word)           cycle  <- mkReg(0);

    // Pipeline Registers
    Reg#(ProgramCounter) pc     <- mkReg(initialProgramCounter);
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

    function Tuple2#(Bool, Bool) instructionHasGPRArguments(Word32 instruction);
        return case(instruction[6:0])
            // 'b1100111: return tuple2(True, False);  // JALR
            // 'b1100011: return tuple2(True, True);   // Branches
            'b0000011: return tuple2(True, False);  // Loads
            // 'b0100011: return tuple2(True, True);   // Stores
            // 'b0010011: return tuple2(True, False);  // ALU immediate
            // 'b0110011: return tuple2(True, True);   // ALU
            // 'b0001111: return tuple2(True, False);  // FENCE
            default:   return tuple2(False, False); // Everything else
        endcase;
    endfunction

    function Bool detectLoadHazard(IF_ID if_id_, ID_EX id_ex_);
        Bool loadHazard = False;
        match { .needsRs1, .needsRs2 } = instructionHasGPRArguments(id_ex_.common.instruction);

        if (needsRs1 && id_ex_.common.instruction[11:7] == if_id.common.instruction[19:15]) begin
            loadHazard = True;
        end else if (needsRs1 && id_ex_.common.instruction[11:7] == if_id.common.instruction[24:20]) begin
            loadHazard = True;
        end
        return loadHazard;
    endfunction

    rule pipeline;
        //
        // Forward declarations of intermediate pipeline structures
        //
        ProgramCounter pc_;
        IF_ID  if_id_;
        ID_EX  id_ex_;
        EX_MEM ex_mem_;
        MEM_WB mem_wb_;
        PipelineRegisterCommon wb_out_;

        //
        // Process the pipeline
        //
        if_id_  <- fetchStage.fetch(pc, ex_mem);
        id_ex_  <- decodeStage.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2);
        ex_mem_ <- executeStage.execute(id_ex);
        mem_wb_ <- memoryStage.memory(ex_mem);
        wb_out_ <- writebackStage.writeback(mem_wb, gprFile.gprWritePort);

        $display("-----------------------------");
        $display("Cycle : %0d", cycle);
        $display("PC    : $%0x", pc);
        $display("IF_ID : ", fshow(if_id_));
        $display("ID_EX : ", fshow(id_ex_));
        $display("EX_MEM: ", fshow(ex_mem_));
        $display("MEM_WB: ", fshow(mem_wb_));
        $display("WB_OUT: ", fshow(wb_out_));

        //
        // Check for traps (and update the program counter to the trap handler if one exists)
        //
        if (wb_out_.trap matches tagged Valid .trap) begin
            pc_ <- csrFile.trapController.beginTrap(trap);
        end else begin
            pc_ = if_id_.nextProgramCounter;
        end

        $display("NEXT_PC: $%0x", pc_);

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
            $display("Fetch Stalled");
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
                programCounter: wb_out_.programCounter,
                instruction:    wb_out_.instruction
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
