import PGRV::*;

import BranchPrediction::*;
import MemoryIO::*;
import PipelineRegisters::*;
import Trap::*;

import Assert::*;
import ClientServer::*;
import DReg::*;
import FIFO::*;
import GetPut::*;
import SpecialFIFOs::*;

`undef ENABLE_SPEW

typedef enum {
    WAITING_FOR_FETCH_REQUEST,  // IDLE
    WAITING_FOR_FETCH_RESPONSE
} FetchState deriving(Bits, Eq, FShow);

interface FetchStage;
    method ActionValue#(IF_ID) fetch(ProgramCounter programCounter, EX_MEM ex_mem, Bit#(1) epoch);
    method Bool isStalled;

    interface ReadOnlyMemoryClient#(XLEN, 32) instructionMemoryClient;
endinterface

module mkFetchStage#(BranchPredictor branchPredictor)(FetchStage);
    RWire#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequest    <- mkRWire;
    FIFO#(FallibleMemoryResponse#(32))       instructionMemoryResponses  <- mkFIFO;
    RWire#(FallibleMemoryResponse#(32))      instructionMemoryResponse   <- mkRWire;

    Reg#(FetchState)  state    <- mkReg(WAITING_FOR_FETCH_REQUEST);
    Wire#(FetchState) curState <- mkWire;

    rule queueTowire;
        let response <- pop(instructionMemoryResponses);
        instructionMemoryResponse.wset(response);
    endrule

    method ActionValue#(IF_ID) fetch(ProgramCounter pc, EX_MEM ex_mem, Bit#(1) epoch);
        IF_ID if_id = defaultValue;

        let nextState = state;

        case(state)
            WAITING_FOR_FETCH_REQUEST: begin
                instructionMemoryRequest.wset(ReadOnlyMemoryRequest {
                    byteen: 'b1111,
                    address: pc
                });

                nextState = WAITING_FOR_FETCH_RESPONSE;
            end

            WAITING_FOR_FETCH_RESPONSE: begin
`ifdef ENABLE_SPEW
                $display("Looking for response...");
`endif
                if (instructionMemoryResponse.wget matches tagged Valid .response) begin
`ifdef ENABLE_SPEW
                    if (ex_mem.cond) begin
                        $display("FETCH: Redirected PC to $%0x", npc);
                    end
`endif

                    if_id.common.ir         = response.data;
                    if_id.common.pc         = pc;
                    if_id.common.isBubble   = False;

                    let npc = (ex_mem.cond ? ex_mem.aluOutput : branchPredictor.nextProgramCounter(if_id.common));

                    if_id.epoch             = epoch;
                    if_id.npc               = npc;

                    if (response.denied) begin
                        if_id.common.trap = tagged Valid Trap {
                            cause: exception_INSTRUCTION_ACCESS_FAULT,
                            isInterrupt: False,
                            tval: if_id.common.pc
                        };
                    end

`ifdef ENABLE_SPEW
                    $display("FETCH: Found response...");

                    $display("FETCH: Fetching instruction for $%0x.", npc);
`endif
                    // Fetch the next instruction
                    instructionMemoryRequest.wset(ReadOnlyMemoryRequest {
                        byteen: 'b1111,
                        address: npc
                    });
                end
            end
        endcase

        state <= nextState;
        return if_id;
    endmethod

    method Bool isStalled;
        return (state == WAITING_FOR_FETCH_RESPONSE);
    endmethod

    interface ReadOnlyMemoryClient instructionMemoryClient = toGPClient(instructionMemoryRequest, instructionMemoryResponses);
endmodule
