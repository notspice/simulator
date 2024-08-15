pub const GateInitError = error {
    InvalidGateType,
    WrongNumberOfInputs,
    UnnecessaryExternalState,
    MissingExternalState,
    NodeNotFound
};
pub const ParserError = error {
    ColonNotFound,
    ArrowNotFound,
    InvalidGateInstanceName,
    UnexpectedArrowCount,
    UnknownKeyword,
    KeywordNotAlphanumeric,
    UnexpectedCharacter,
    UnexpectedBracket,
    MissingBracket,
    InvalidModuleType,
    MisplacedModule,
    MissingSemicolon,
} || GateInitError;

pub const SimulationError = error {
    TooManyNodeDrivers,
    InvalidGateConnection
};