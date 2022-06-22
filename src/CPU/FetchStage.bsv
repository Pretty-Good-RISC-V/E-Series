import PGRV::*;

import MemoryIO::*;
import PipelineRegisters::*;
import Trap::*;

import ClientServer::*;
import FIFO::*;
import GetPut::*;

typedef enum {
    WAITING_FOR_FETCH_REQUEST,  // IDLE
    WAITING_FOR_FETCH_RESPONSE
} FetchState deriving(Bits, Eq, FShow);

interface FetchStage;
    method ActionValue#(IF_ID) fetch(ProgramCounter programCounter, EX_MEM ex_mem, Bit#(1) epoch);
    method Bool isStalled;
    interface ReadOnlyMemoryClient#(XLEN, 32) instructionMemoryClient;
endinterface

module mkFetchStage(FetchStage);
    RWire#(ReadOnlyMemoryRequest#(XLEN, 32)) instructionMemoryRequest  <- mkRWire;
    RWire#(FallibleMemoryResponse#(32))      instructionMemoryResponse <- mkRWire;

    Reg#(FetchState) state <- mkReg(WAITING_FOR_FETCH_REQUEST);
    Wire#(FetchState) curState <- mkWire;

    method ActionValue#(IF_ID) fetch(ProgramCounter pc, EX_MEM ex_mem, Bit#(1) epoch);
        IF_ID if_id = defaultValue;

        let npc = pc;
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
                if (instructionMemoryResponse.wget matches tagged Valid .response) begin
                    npc = (ex_mem.cond ? ex_mem.aluOutput : pc + 4);

                    if_id.common.ir         = response.data;
                    if_id.common.pc         = pc;
                    if_id.common.isBubble   = False;
                    if_id.epoch             = epoch;
                    if_id.npc               = npc;

                    if (response.denied) begin
                        if_id.common.trap = tagged Valid Trap {
                            cause: exception_INSTRUCTION_ACCESS_FAULT,
                            isInterrupt: False
                        };
                    end

                    nextState = WAITING_FOR_FETCH_REQUEST;
                end
            end
        endcase

        state <= nextState;
        return if_id;
    endmethod

    method Bool isStalled;
        return (state == WAITING_FOR_FETCH_RESPONSE);
    endmethod

    interface ReadOnlyMemoryClient instructionMemoryClient = toGPClient(instructionMemoryRequest, instructionMemoryResponse);
endmodule
