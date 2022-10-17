import PGRV::*;

typedef struct {
    Bit#(4) cause;  // Either exception or interrupt
    Bool isInterrupt;
    Word tval;
} Trap deriving(Bits, Eq, FShow);
