pub const GateInitError = error {
    InvalidGateType,
    WrongNumberOfInputs,
    UnnecessaryExternalState,
    MissingExternalState
};

pub const SimulationError = error {
    TooManyNodeDrivers,
    InvalidGateConnection
};