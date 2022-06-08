import PGRV::*;
import ALU::*;

import Assert::*;

typedef struct {
    RVALUOperator operator;    
    Word operand1;
    Word operand2;
    Word expectedResult;
    Bool expectedIllegalOpcode;
} ALUTestCase deriving(Bits, Eq, FShow);

(* synthesize *)
module mkALU_ESeries_tb(Empty);
    Reg#(Word) testNumber <- mkReg(0);

`ifdef RV32
    Integer arraySize = 18;
`elsif RV64
    Integer arraySize = 20;
`endif

    ALUTestCase testCases[arraySize] = {
        ALUTestCase { 
            operator: alu_ADD,  
            operand1: 0,          
            operand2: 0,   
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_ADD,  
            operand1: 5,          
            operand2: 7,    
            expectedResult: 12,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_ADD,  
            operand1: 5,          
            operand2: -7,   
            expectedResult: -2,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SUB,  
            operand1: 0,          
            operand2: 0,    
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SUB,  
            operand1: 5,          
            operand2: 7,    
            expectedResult: -2,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SUB,  
            operand1: 5,          
            operand2: -7,   
            expectedResult: 12,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_AND,  
            operand1: 'ha7,       
            operand2: 'h65, 
            expectedResult: 'h25,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_OR,   
            operand1: 'ha7,       
            operand2: 'h65, 
            expectedResult: 'he7,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_XOR,  
            operand1: 'ha7,       
            operand2: 'h65, 
            expectedResult: 'hc2,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLTU, 
            operand1: 90,         
            operand2: 100,  
            expectedResult: 1,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLTU, 
            operand1: 100,        
            operand2: 90,   
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLTU, 
            operand1: 100,        
            operand2: 100,  
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLT,  
            operand1: -1,         
            operand2: 1,    
            expectedResult: 1,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLT,  
            operand1: 1,          
            operand2: -1,   
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLT,  
            operand1: -1,         
            operand2: -1,   
            expectedResult: 0,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLL,  
            operand1: 'hF0F0,     
            operand2: 8,    
            expectedResult: 'hF0F000,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SRA,  
            operand1: -16,        
            operand2: 2,    
            expectedResult: -4,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SRL,  
            operand1: 'hF0F0F0F0, 
            operand2: 4,    
            expectedResult: 'h0F0F0F0F,  
            expectedIllegalOpcode: False 
        }
`ifdef RV64
        ,
        ALUTestCase {
            operator: alu_SRL,  
            operand1: 'hC000_0000_0000_0000, 
            operand2: 62, 
            expectedResult: 3,  
            expectedIllegalOpcode: False 
        },
        ALUTestCase { 
            operator: alu_SLL,  
            operand1: 3, 
            operand2: 62, 
            expectedResult: 'hC000_0000_0000_0000,  
            expectedIllegalOpcode: False 
        }
`endif
    };

    ALU dut <- mkALU;

    rule runme;
        let testCase = testCases[testNumber];
        // Perform the test
        let aluResult = dut.execute(testCase.operator, testCase.operand1, testCase.operand2);

        // Check results
        if (aluResult.illegalOperation != testCase.expectedIllegalOpcode) begin
            $display("FAILED test #%0d - illegal operation not as expected: ", testNumber, fshow(testCase));
            $fatal();
        end

        if (aluResult.result != testCase.expectedResult) begin
            $display("FAILED test #%0d - $%0x != unexpected result: ", testNumber, aluResult.result, fshow(testCase));
            $fatal();
        end

        if (testNumber + 1 >= fromInteger(arraySize)) begin
            $display("    PASS");
            $finish();
        end

        testNumber <= testNumber + 1;
    endrule

endmodule
