//! Contains the runner for the genesis command.

use crate::{
    cli::command::genesis::Args,
    prover::{SP1ICS07TendermintProgram, UpdateClientProgram, VerifyMembershipProgram},
    rpc::TendermintRPCClient,
};
use alloy_sol_types::SolValue;
use ibc_client_tendermint::types::ConsensusState;
use ibc_core_commitment_types::commitment::CommitmentRoot;
use ibc_core_host_types::identifiers::ChainId;
use sp1_ics07_tendermint_shared::types::sp1_ics07_tendermint::{
    ClientState, ConsensusState as SolConsensusState, Height, TrustThreshold,
};

use sp1_sdk::{utils::setup_logger, HashableKey, MockProver, Prover};
use std::{env, path::PathBuf, str::FromStr};
/// The genesis data for the SP1 ICS07 Tendermint contract.
#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct SP1ICS07TendermintGenesis {
    /// The encoded trusted client state.
    trusted_client_state: String,
    /// The encoded trusted consensus state.
    trusted_consensus_state: String,
    /// The encoded key for [`UpdateClientProgram`].
    update_client_vkey: String,
    /// The encoded key for [`VerifyMembershipProgram`].
    verify_membership_vkey: String,
}

/// Creates the `genesis.json` file for the `SP1ICS07Tendermint` contract.
#[allow(clippy::missing_errors_doc, clippy::missing_panics_doc)]
pub async fn run(args: Args) -> anyhow::Result<()> {
    setup_logger();
    if dotenv::dotenv().is_err() {
        log::warn!("No .env file found");
    }

    let tendermint_rpc_client = TendermintRPCClient::default();
    let mock_prover = MockProver::new();
    let (_, update_client_vk) = mock_prover.setup(UpdateClientProgram::ELF);
    let (_, verify_membership_vk) = mock_prover.setup(VerifyMembershipProgram::ELF);

    let trusted_light_block = tendermint_rpc_client
        .get_light_block(args.trusted_block)
        .await?;
    let trusted_height = trusted_light_block.height().value();
    if args.trusted_block.is_none() {
        log::info!("Latest block height: {}", trusted_height);
    }

    let chain_id = ChainId::from_str(trusted_light_block.signed_header.header.chain_id.as_str())?;

    let two_weeks_in_nanos = 14 * 24 * 60 * 60 * 1_000_000_000;
    let trusted_client_state = ClientState {
        chain_id: chain_id.to_string(),
        trust_level: TrustThreshold {
            numerator: 1,
            denominator: 3,
        },
        latest_height: Height {
            revision_number: chain_id.revision_number().try_into()?,
            revision_height: trusted_height.try_into()?,
        },
        is_frozen: false,
        trusting_period: two_weeks_in_nanos,
        unbonding_period: two_weeks_in_nanos,
    };
    let trusted_consensus_state = ConsensusState {
        timestamp: trusted_light_block.signed_header.header.time,
        root: CommitmentRoot::from_bytes(
            trusted_light_block.signed_header.header.app_hash.as_bytes(),
        ),
        next_validators_hash: trusted_light_block
            .signed_header
            .header
            .next_validators_hash,
    };

    let genesis = SP1ICS07TendermintGenesis {
        trusted_consensus_state: hex::encode(
            SolConsensusState::from(trusted_consensus_state).abi_encode(),
        ),
        trusted_client_state: hex::encode(trusted_client_state.abi_encode()),
        update_client_vkey: update_client_vk.bytes32(),
        verify_membership_vkey: verify_membership_vk.bytes32(),
    };

    let fixture_path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(args.genesis_path);
    std::fs::write(
        fixture_path.join("genesis.json"),
        serde_json::to_string_pretty(&genesis).unwrap(),
    )
    .unwrap();

    Ok(())
}