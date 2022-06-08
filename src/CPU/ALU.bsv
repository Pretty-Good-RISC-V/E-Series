import PGRV::*;

typedef struct {
    Word result;
    Bool illegalOperation;
} ALUResult deriving(Bits, Eq, FShow);

interface ALU;
    method ActionValue#(ALUResult) calculate(RVALUOperator aluOperation, Word operand1, Word operand2);
endinterface

module mkALU(ALU);
    function Word setLessThanUnsigned(Word operand1, Word operand2);
        return (operand1 < operand2 ? 1 : 0);
    endfunction

    function Word setLessThan(Word operand1, Word operand2);
        Int#(XLEN) signedOperand1 = unpack(pack(operand1));
        Int#(XLEN) signedOperand2 = unpack(pack(operand2));
        return (signedOperand1 < signedOperand2 ? 1 : 0);
    endfunction

    method ActionValue#(ALUResult) calculate(RVALUOperator aluOperation, Word operand1, Word operand2);
        Word result = ?;
        Bool illegalOperation = False;

        case (aluOperation)
            alu_ADD:    result = operand1 + operand2;
            alu_AND:    result = operand1 & operand2;
            alu_ADD:    result =  (operand1 + operand2);
            alu_SUB:    result =  (operand1 - operand2);
            alu_AND:    result =  (operand1 & operand2);
            alu_OR:     result =  (operand1 | operand2);
            alu_XOR:    result =  (operand1 ^ operand2);
            alu_SLTU:   result =  setLessThanUnsigned(operand1, operand2);
            alu_SLT:    result =  setLessThan(operand1, operand2);
`ifdef RV32
            alu_SLL:    result =  (operand1 << operand2[4:0]);
            alu_SRA:    result =  signedShiftRight(operand1, operand2[4:0]);
            alu_SRL:    result =  (operand1 >> operand2[4:0]);
`elsif RV64
            alu_SLL:    result =  (operand1 << operand2[5:0]);
            alu_SRA:    result =  signedShiftRight(operand1, operand2[5:0]);
            alu_SRL:    result =  (operand1 >> operand2[5:0]);

            alu_ADD32: begin
                let tmp = operand1[31:0] + operand2[31:0];
                result =  signExtend(tmp[31:0]);
            end
            alu_SUB32: begin
                let tmp = (operand1[31:0] - operand2[31:0]);
                result =  signExtend(tmp[31:0]);
            end
            alu_SLL32: begin
                let tmp = (operand1[31:0] << operand2[4:0]);
                result =  signExtend(tmp[31:0]);
            end
            alu_SRA32: begin
                let tmp = signedShiftRight(operand1[31:0], operand2[4:0]);
                result =  signExtend(tmp[31:0]);
            end
            alu_SRL32: begin
                let tmp = (operand1[31:0] >> operand2[4:0]);
                result =  signExtend(tmp[31:0]);
            end     
`endif   
            default: begin
                $display("ALU: Illegal ALU operation: $0x", aluOperation);
                result = 0;
                illegalOperation = True;
            end
        endcase

        return ALUResult {
            result: result,
            illegalOperation: illegalOperation
        };
    endmethod
endmodule
