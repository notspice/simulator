pub const GateInitError = error {
    InvalidGateType,
    WrongNumberOfInputs,
    UnnecessaryExternalState,
    MissingExternalState,
    NodeNotFound
};
pub const ParserError = error {
    ColonNotFound,
    InvalidGateInstanceName,
    UnexpectedArrowCount,
    UnknownKeyword,
    KeywordNotAlphanumeric,
    UnexpectedCharacter
} || GateInitError;

pub const SimulationError = error {
    TooManyNodeDrivers,
    InvalidGateConnection
};