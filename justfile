set dotenv-load

# Build riscv elf file using `~/.sp1/bin/cargo-prove`
build-programs:
  just generate-abi
  cd programs/update-client && ~/.sp1/bin/cargo-prove prove build
  mv elf/riscv32im-succinct-zkvm-elf elf/update-client-riscv32im-succinct-zkvm-elf
  @echo "ELF created at 'elf/update-client-riscv32im-succinct-zkvm-elf'"
  cd programs/membership && ~/.sp1/bin/cargo-prove prove build
  mv elf/riscv32im-succinct-zkvm-elf elf/membership-riscv32im-succinct-zkvm-elf
  @echo "ELF created at 'elf/membership-riscv32im-succinct-zkvm-elf'"
  cd programs/uc-and-membership && ~/.sp1/bin/cargo-prove prove build
  mv elf/riscv32im-succinct-zkvm-elf elf/uc-and-membership-riscv32im-succinct-zkvm-elf
  @echo "ELF created at 'elf/uc-and-membership-riscv32im-succinct-zkvm-elf'"

# Build the operator executable using `cargo build` command
build-operator:
  @echo "Building the programs for the operator..."
  just build-programs
  @echo "Building the operator executable..."
  cargo build --bin operator --locked --release
  @echo "Built the operator executable"

# Build the contracts using `forge build` command after cleaning up the cache and output directories
build-contracts:
  @echo "Cleaning up the contracts cache and output directories..."
  -rm -r contracts/cache contracts/out # `-` is used to ignore the error if the directories do not exist
  @echo "Installing the dependencies..."
  bun install && forge install
  @echo "Building the contracts..."
  forge build

# Run the Solidity tests using `forge test` command
test-foundry:
  @echo "Cleaning up the contracts cache and output directories..."
  -rm -r contracts/cache contracts/out # `-` is used to ignore the error if the directories do not exist
  forge test -vvv

# Run the Rust tests using `cargo test` command (excluding the sp1-ics07-tendermint-update-client crate)
test-cargo:
  cargo test --workspace --exclude sp1-ics07-tendermint-update-client --exclude sp1-ics07-tendermint-membership --locked --all-features

# Generate the `genesis.json` file using $TENDERMINT_RPC_URL in the `.env` file
genesis:
  @echo "Generating the genesis file for the Celestia Mocha testnet"
  @echo "Building the program..."
  just build-programs
  @echo "Generating the genesis file..."
  RUST_LOG=info cargo run --bin operator --release -- genesis

# Generate the fixture files for the Celestia Mocha testnet using the prover parameter.
# The prover parameter should be one of: ["mock", "network", "local"]
# This generates the fixtures for all programs in parallel using GNU parallel.
# If prover is set to network, this command requires the `SP1_PRIVATE_KEY` environment variable to be set.
fixtures prover:
  @echo "Generating fixtures for the Celestia Mocha testnet"
  @echo "Building the program..."
  just build-programs
  @echo "Building the operator..."
  just build-operator
  @echo "Generating fixtures... This may take a while (up to 20 minutes)"
  parallel --progress --shebang --ungroup -j 4 ::: \
    "RUST_LOG=info SP1_PROVER={{prover}} TENDERMINT_RPC_URL='https://rpc.celestia-mocha.com/' ./target/release/operator fixtures update-client --trusted-block 2330000 --target-block 2330010 -o 'contracts/fixtures/update_client_fixture.json'" \
    "sleep 15 && RUST_LOG=info SP1_PROVER={{prover}} TENDERMINT_RPC_URL='https://rpc.celestia-mocha.com/' ./target/release/operator fixtures update-client-and-membership --key-paths clients/07-tendermint-0/clientState,clients/07-tendermint-001/clientState --trusted-block 2330000 --target-block 2330010 -o 'contracts/fixtures/uc_and_memberships_fixture.json'" \
    "sleep 30 && RUST_LOG=info SP1_PROVER={{prover}} TENDERMINT_RPC_URL='https://rpc.celestia-mocha.com/' ./target/release/operator fixtures membership --key-paths clients/07-tendermint-0/clientState,clients/07-tendermint-001/clientState --trusted-block 2330000 -o 'contracts/fixtures/memberships_fixture.json'"
  @echo "Fixtures generated at 'contracts/fixtures'"

# Generate the `SP1ICS07Tendermint.json` file containing the ABI of the SP1ICS07Tendermint contract
# Requires `jq` to be installed on the system
# Requires `abigen` to be installed on the system to generate the go bindings for e2e tests
generate-abi:
  just build-contracts
  jq '.abi' contracts/out/SP1ICS07Tendermint.sol/SP1ICS07Tendermint.json > contracts/abi/SP1ICS07Tendermint.json
  @echo "ABI file created at 'contracts/abi/SP1ICS07Tendermint.json'"
  @echo "Generating go bindings for the end-to-end tests..."
  abigen --abi contracts/abi/SP1ICS07Tendermint.json --pkg sp1ics07tendermint --type Contract --out e2e/interchaintestv8/types/sp1ics07tendermint/contract.go
  @echo "Done."

# Deploy the SP1ICS07Tendermint contract to the Eth Sepolia testnet if the `.env` file is present
deploy-contracts:
  @echo "Deploying the SP1ICS07Tendermint contract"
  just genesis
  just build-contracts
  @echo "Deploying the contract..."
  forge script contracts/script/SP1ICS07Tendermint.s.sol --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

# Run the operator using the `cargo run --bin operator` command.
# This command requires the `.env` file to be present in the root directory.
operator:
  just generate-abi
  RUST_LOG=info cargo run --bin operator --release -- start

# Run the e2e tests
test-e2e testname:
  @echo "Cleaning up the contracts cache and output directories..."
  -rm -r contracts/cache contracts/out # `-` is used to ignore the error if the directories do not exist
  @echo "Running {{testname}} test..."
  cd e2e/interchaintestv8 && go test -v -run=TestWithSP1ICS07TendermintTestSuite/{{testname}} -timeout 40m

# Lint and fix the Rust, Solidity, and Go code using `cargo fmt`, `forge fmt`, and `golanci-lint` commands
lint-fix:
  @echo "Linting the Rust code..."
  cargo fmt
  @echo "Linting the Solidity code..."
  forge fmt
  @echo "Linting the Go code..."
  cd e2e/interchaintestv8 && golangci-lint run --fix

# Lint the Rust, Solidity, and Go code using `cargo clippy`, `forge fmt`, `solhint`, and `golanci-lint` commands
lint-check:
  @echo "Linting the Rust code..."
  cargo clippy --all-targets --all-features -- -D warnings
  @echo "Linting the Solidity code..."
  forge fmt --check && bun solhint -c .solhint.json 'contracts/**/*.sol'
  @echo "Linting the Go code..."
  cd e2e/interchaintestv8 && golangci-lint run
