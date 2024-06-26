set dotenv-load

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

# Generate the `genesis.json` file using $TENDERMINT_RPC_URL in the `.env` file
genesis:
  @echo "Generating the genesis file for the Celestia Mocha testnet"
  @echo "Building the program..."
  just build-program
  @echo "Generating the genesis file..."
  RUST_LOG=info cargo run --bin genesis --release

# Generate the `mock_fixture.json` file for the Celestia Mocha testnet using the mock prover
mock-fixtures:
  @echo "Generating mock fixtures for the Celestia Mocha testnet"
  @echo "Building the program..."
  just build-program
  @echo "Generating the mock fixtures..."
  RUST_BACKTRACE=full RUST_LOG=info SP1_PROVER="mock" TENDERMINT_RPC_URL="https://rpc.celestia-mocha.com/" cargo run --bin fixture --release -- --trusted-block 2110658 --target-block 2110668
  @echo "Mock fixtures generated at 'contracts/fixtures/mock_fixture.json'"

# Generate the `fixture.json` file for the Celestia Mocha testnet using the network prover.
# This command requires the `.env` file to be present in the root directory.
network-fixtures:
  @echo "Generating fixtures for the Celestia Mocha testnet"
  @echo "Building the program..."
  just build-program
  @echo "Generating fixtures... This may take a while (up to 20 minutes)"
  RUST_BACKTRACE=full RUST_LOG=info SP1_PROVER="network" TENDERMINT_RPC_URL="https://rpc.celestia-mocha.com/" cargo run --bin fixture --release -- --trusted-block 2110658 --target-block 2110668
  @echo "Fixtures generated at 'contracts/fixtures/fixture.json'"

# Generate the `SP1ICS07Tendermint.json` file containing the ABI of the SP1ICS07Tendermint contract
generate-abi:
  cd contracts && forge install && forge build
  cp contracts/out/SP1ICS07Tendermint.sol/SP1ICS07Tendermint.json contracts/abi/
  @echo "ABI file created at 'contracts/abi/SP1ICS07Tendermint.json'"

# Deploy the SP1ICS07Tendermint contract to the Eth Sepolia testnet if the `.env` file is present
deploy-contracts:
  @echo "Deploying the SP1ICS07Tendermint contract to the Sepolia testnet"
  just genesis
  cd contracts && forge install
  @echo "Deploying the contract..."
  cd contracts && forge script script/SP1ICS07Tendermint.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Run the operator using the `cargo run --bin operator` command.
# This command requires the `.env` file to be present in the root directory.
operator:
  RUST_LOG=info cargo run --bin operator --release
