// core types used throughout rio
// zero dependencies - foundation layer

pub const IOMode = enum {
    direct,
    buffered,
    sync,
};

pub const IOPattern = enum {
    sequential,
    random,
    zero,
    ones,
    random_compressible,
};
