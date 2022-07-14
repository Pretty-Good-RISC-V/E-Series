import PGRV::*;
import CSRFile::*;
import DecodeStage::*;
import GPRFile::*;
import PipelineRegisters::*;

import Assert::*;
import StmtFSM::*;

(* synthesize *)
module mkDecodeStage_tb(Empty);
    GPRFile gprFile <- mkGPRFile;
    DecodeStage dut <- mkDecodeStage;
    CSRFile csrFile <- mkCSRFile;

    Reg#(Word) gprIndex <- mkRegU;
    Stmt testMachine = 
        (seq
            // Clear GPRs
            for (gprIndex <= 0; gprIndex < 32; gprIndex <= gprIndex + 1)
                gprFile.gprWritePort.write(truncate(gprIndex), 0);
    
            // 0:	00a00093          	li	ra,10
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000004 };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000004, a: 'h00000000, b: 'h00000000, isBValid: True, imm: 'h0000000a };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");

                    // Simulated WB stage
                    gprFile.gprWritePort.write(result.common.ir[11:7], result.imm);
               endaction
            endseq

            // 4:	01400113          	li	sp,20
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h01400113, pc: 'h00000004, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000008 };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h01400113, pc: 'h00000004, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000008, a: 'h00000000, b: 'h00000000, isBValid: True, imm: 'h00000014 };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");

                    // Simulated WB stage
                    gprFile.gprWritePort.write(result.common.ir[11:7], result.imm);
               endaction
            endseq

            // 8:	01e00493          	li	s1,30
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h01e00493, pc: 'h00000008, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h01e00493, pc: 'h00000008, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c, a: 'h00000000, b: 'h00000000, isBValid: True, imm: 'h0000001e };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");

                    // Simulated WB stage
                    gprFile.gprWritePort.write(result.common.ir[11:7], result.imm);
               endaction
            endseq

            // c:	002081b3          	add	gp,ra,sp
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h002081b3, pc: 'h0000000c, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h002081b3, pc: 'h0000000c, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c, a: 'h0000000a, b: 'h00000014, isBValid: True, imm: 'h00000002 };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");

                    // Simulated WB stage
                    gprFile.gprWritePort.write(result.common.ir[11:7], 'd30); // 30 = ra(10) + sp(20)
               endaction
            endseq

            // 10:	00919463          	bne	gp,s1,18 <_fail>
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h00919463, pc: 'h00000010, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000014 };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h00919463, pc: 'h00000010, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000014, a: 'h0000001e, b: 'h0000001e, isBValid: True, imm: 'h00000008 };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");
               endaction
            endseq

            // 14:	0000006f          	j	14 <_pass>
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000014, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018 };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000014, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018, a: 'h00000000, b: 'h00000000, isBValid: True, imm: 'h00000000 };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");
               endaction
            endseq

            // 18:	0000006f          	j	14 <_fail>
            seq
               action
                    let if_id = IF_ID { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000018, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018 };
                    let result <- dut.decode(if_id, gprFile.gprReadPort1, gprFile.gprReadPort2, csrFile.csrReadPort);

                    let expected = ID_EX { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000018, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018, a: 'h00000000, b: 'h00000000, isBValid: True, imm: 'h00000000 };
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "ID_EX should match what's expected");
               endaction
            endseq

            $display("    PASS");
            $finish();
        endseq);

    FSM tests <- mkFSM(testMachine);

    Reg#(Bool) started <- mkReg(False);
    rule test(!started);
        started <= True;
        tests.start;
    endrule
endmodule
