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
    InvalidGateInstanceName
} || GateInitError;

pub const SimulationError = error {
    TooManyNodeDrivers,
    InvalidGateConnection
};