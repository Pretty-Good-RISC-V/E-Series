import PGRV::*;

typedef struct {
    Bool taken;
    Bool illegalOperation;
} BranchResult deriving(Bits, Eq, FShow);

interface BranchUnit;
    method ActionValue#(BranchResult) calculate(RVBranchOperator branchOperation, Word operand1, Word operand2);
endinterface

module mkBranchUnit(BranchUnit);
    method ActionValue#(BranchResult) calculate(RVBranchOperator branchOperation, Word operand1, Word operand2);
        Bool taken = False;
        Bool illegalOperation = False;

        case (branchOperation)
            default: begin
                $display("BranchUnit: Illegal branch operation: $0x", branchOperation);
                illegalOperation = True;
            end
        endcase

        return BranchResult {
            taken: taken,
            illegalOperation: illegalOperation
        };
    endmethod
endmodule
