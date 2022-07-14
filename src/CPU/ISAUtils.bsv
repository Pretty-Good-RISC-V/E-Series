import PGRV::*;

 function Bool instructionHasRD(Word32 instruction);
    return case (instruction[6:0])
        'b1110011: return True; // CSR
        'b0110111: return True; // LUI
        'b0010111: return True; // AUIPC
        'b1101111: return True; // JAL
        'b1100111: return True; // JALR
        'b0000011: return True; // LOAD
        'b0010011: return True; // OPIM
        'b0110011: return True; // OP
        default: return False;
    endcase;
endfunction

function Tuple2#(Bool, Bool) instructionHasGPRArguments(Word32 instruction);
    // Returns tuple indicating if instruction has an RS1 and/or RS2 arguments.
    return case(instruction[6:0])
        'b1110011: return tuple2(!unpack(instruction[14]), False);
        'b1100111: return tuple2(True, False);  // JALR
        'b1100011: return tuple2(True, True);   // Branches
        'b0000011: return tuple2(True, False);  // Loads
        'b0100011: return tuple2(True, True);   // Stores
        'b0010011: return tuple2(True, False);  // ALU immediate
        'b0110011: return tuple2(True, True);   // ALU
        'b0001111: return tuple2(True, False);  // FENCE
        default:   return tuple2(False, False); // Everything else
    endcase;
endfunction
