import PGRV::*;
import ExecuteStage::*;
import PipelineRegisters::*;

import Assert::*;
import StmtFSM::*;
import GetPut::*;

(* synthesize *)
module mkExecuteStage_tb(Empty);
    ExecuteStage dut <- mkExecuteStage;
    Reg#(Bit#(1)) epoch <- mkReg(0);

    Stmt testMachine = 
        (seq
            // 0:	00a00093          	li	ra,10
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000004, a: 'h00000000, b: 'h00000000, imm: 'h0000000a };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h00a00093, pc: 'h00000000, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h0000000a, b: 'h00000000, cond: False };

                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
                endaction
            endseq

            // 4:	01400113          	li	sp,20
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h01400113, pc: 'h00000004, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000008, a: 'h00000000, b: 'h00000000, imm: 'h00000014 };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h01400113, pc: 'h00000004, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h000000014, b: 'h00000000, cond: False };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
                endaction
            endseq

            // 8:	01e00493          	li	s1,30
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h01e00493, pc: 'h00000008, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c, a: 'h00000000, b: 'h00000000, imm: 'h0000001e };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h01e00493, pc: 'h00000008, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h00000001e, b: 'h00000000, cond: False };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
                endaction
            endseq

            // c:	002081b3          	add	gp,ra,sp
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h002081b3, pc: 'h0000000c, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h0000000c, a: 'h0000000a, b: 'h00000014, imm: 'h00000002 };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h002081b3, pc: 'h0000000c, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h00000001e, b: 'h00000014, cond: False };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
               endaction
            endseq

            // 10:	00919463          	bne	gp,s1,18 <_fail>
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h00919463, pc: 'h00000010, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000014, a: 'h0000001e, b: 'h0000001e, imm: 'h00000008 };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h00919463, pc: 'h00000010, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h000000018, b: 'h0000001e, cond: False };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
               endaction
            endseq

            // 14:	0000006f          	j	14 <_pass>
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000014, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018, a: 'h00000000, b: 'h00000000, imm: 'h00000000 };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000014, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h000000014, b: 'h0000000, cond: True };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
               endaction
            endseq

            // 18:	0000006f          	j	14 <_fail>
            seq
               action
                    let id_ex = ID_EX { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000018, isBubble: False, trap: tagged Invalid  }, epoch: 'h0, npc: 'h00000018, a: 'h00000000, b: 'h00000000, imm: 'h00000000 };
                    let result <- dut.execute(id_ex, epoch);

                    let expected = EX_MEM { common: PipelineRegisterCommon { ir: 'h0000006f, pc: 'h00000018, isBubble: False, trap: tagged Invalid  }, aluOutput: 'h000000018, b: 'h0000000, cond: True };
                    
                    $display("result  : ", fshow(result));
                    $display("expected: ", fshow(expected));
                    dynamicAssert(result == expected, "Result should match what's expected");
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
