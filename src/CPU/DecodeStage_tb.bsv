import PGRV::*;
import DecodeStage::*;
import GPRFile::*;
import PipelineRegisters::*;

import Assert::*;
import Connectable::*;
import GetPut::*;

typedef enum {
    SETUP,
    TEST
} State deriving(Bits, Eq, FShow);

(* synthesize *)
module mkDecodeStage_tb(Empty);
    GPRFile gprFile <- mkGPRFile;
    DecodeStage dut <- mkDecodeStage;

    Reg#(State) state <- mkReg(SETUP);

    rule setup(state == SETUP);
        $display("Setting up...");
        gprFile.gprWritePort.write(1, 99);
        state <= TEST;
    endrule

    rule test(state == TEST);
        $display("Testing...");
        let if_id = IF_ID {
            common: PipelineRegisterCommon {
                instruction: {7'b0, 5'h1, 5'h2, 3'b0, 5'h3, 7'b0110011 },
                programCounter: 'h8000_0000,
                isBubble: False,
                exceptionCause: tagged Invalid
            },
            nextProgramCounter: 'h8000_0004
        };

        let id_ex <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2);

        dynamicAssert(!isValid(id_ex.common.exceptionCause), "ExceptionCause should be invalid");
        dynamicAssert(id_ex.b == 99, "RS1 should be 2");
        
        $display("    PASS");
        $finish();
    endrule
endmodule
