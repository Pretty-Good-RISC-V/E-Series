import PGRV::*;

typedef struct {
    Bool taken;
    Bool illegalOperation;
} BranchResult deriving(Bits, Eq, FShow);

interface BranchUnit;
    method ActionValue#(BranchResult) isTaken(RVBranchOperator branchOperation, Word operand1, Word operand2);
endinterface

module mkBranchUnit(BranchUnit);
    method ActionValue#(BranchResult) isTaken(RVBranchOperator branchOperation, Word operand1, Word operand2);
        Bool taken = False;
        Bool illegalOperation = False;

        case (branchOperation)
            branch_BEQ: begin
                taken = operand1 == operand2;
            end

            branch_BNE: begin
                taken = operand1 != operand2;
            end

            branch_BLT: begin
                Int#(XLEN) o1 = unpack(operand1);
                Int#(XLEN) o2 = unpack(operand2);
                taken = o1 < o2;
            end

            branch_BGE: begin
                Int#(XLEN) o1 = unpack(operand1);
                Int#(XLEN) o2 = unpack(operand2);
                taken = o1 >= o2;
            end

            branch_BLTU: begin
                taken = operand1 < operand2;
            end

            branch_BGEU: begin
                taken = operand1 >= operand2;
            end

            default: begin
                illegalOperation = True;
            end
        endcase

        return BranchResult {
            taken: taken,
            illegalOperation: illegalOperation
        };
    endmethod
endmodule
