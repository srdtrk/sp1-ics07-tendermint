# Build riscv elf file using `cargo prove build` command
build-program:
  cd programs/update-client && cargo prove build
  @echo "ELF created at 'program/elf/riscv32im-succinct-zkvm-elf'"

# Run the Solidity tests using `forge test` command
test-foundry:
  cd contracts && forge test -vvv

# Run the Rust tests using `cargo test` command (excluding the sp1-ics07-tendermint-update-client crate)
test-cargo:
  cargo test --workspace --exclude sp1-ics07-tendermint-update-client --locked --all-features
