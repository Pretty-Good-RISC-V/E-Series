import PGRV::*;

typedef struct {
    Bit#(4) cause;  // Either exception or interrupt
    Bool isInterrupt;
} Trap deriving(Bits, Eq, FShow);
