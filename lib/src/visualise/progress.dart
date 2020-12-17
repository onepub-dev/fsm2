typedef Progress = void Function(String line);

Progress noOp(String line) => (line) {};
