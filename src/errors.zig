pub const ProgramErrors = error{
    INVALID_INSTRUCTION,
    JUMP_OUT_OF_BOUNDS,
    STACK_OVERFLOW,
    // http://devernay.free.fr/hacks/chip8/C8TECH10.HTM#3.0
    VF_WRITE_FORBIDDEN,
};

// Errors specific to this runtime
pub const RuntimeErrors = error{
    NOT_IMPLEMENTED,
    ASSERTION_ERROR, // for things that can't happen
    INSUFFICIENT_BUFFER,
    // INTERNAL_ERROR,
};
