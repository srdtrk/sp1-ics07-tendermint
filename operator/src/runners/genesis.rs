//! Contains the runner for the genesis command.

use crate::{
    cli::command::genesis::Args,
    helpers::light_block::LightBlockExt,
    programs::{
        MembershipProgram, SP1Program, UpdateClientAndMembershipProgram, UpdateClientProgram,
    },
    rpc::TendermintRpcExt,
};
use alloy_sol_types::SolValue;
use serde_with::serde_as;
use sp1_ics07_tendermint_solidity::sp1_ics07_tendermint::ConsensusState as SolConsensusState;
use sp1_sdk::{utils::setup_logger, HashableKey};
use std::path::PathBuf;
use tendermint_light_client_verifier::types::{LightBlock, TrustThreshold};
use tendermint_rpc::HttpClient;

/// The genesis data for the SP1 ICS07 Tendermint contract.
#[serde_as]
#[derive(Debug, Clone, serde::Deserialize, serde::Serialize)]
#[serde(rename_all = "camelCase")]
#[allow(clippy::module_name_repetitions)]
pub struct SP1ICS07TendermintGenesis {
    /// The encoded trusted client state.
    #[serde_as(as = "serde_with::hex::Hex")]
    pub trusted_client_state: Vec<u8>,
    /// The encoded trusted consensus state.
    #[serde_as(as = "serde_with::hex::Hex")]
    pub trusted_consensus_state: Vec<u8>,
    /// The encoded key for [`UpdateClientProgram`].
    update_client_vkey: String,
    /// The encoded key for [`MembershipProgram`].
    membership_vkey: String,
    /// The encoded key for [`UpdateClientAndMembershipProgram`].
    uc_and_membership_vkey: String,
}

impl SP1ICS07TendermintGenesis {
    /// Creates a new genesis instance by reading the environment variables
    /// and making the necessary RPC calls.
    #[allow(clippy::missing_errors_doc)]
    pub async fn from_env(
        trusted_light_block: &LightBlock,
        trusting_period: Option<u32>,
        trust_level: TrustThreshold,
    ) -> anyhow::Result<Self> {
        setup_logger();
        if dotenv::dotenv().is_err() {
            log::warn!("No .env file found");
        }

        let tm_rpc_client = HttpClient::from_env();

        let unbonding_period = tm_rpc_client
            .sdk_staking_params()
            .await?
            .unbonding_time
            .ok_or_else(|| anyhow::anyhow!("No unbonding time found"))?
            .seconds
            .try_into()?;

        // Defaults to the recommended TrustingPeriod: 2/3 of the UnbondingPeriod
        let trusting_period = trusting_period.unwrap_or(2 * (unbonding_period / 3));
        if trusting_period > unbonding_period {
            return Err(anyhow::anyhow!(
                "Trusting period cannot be greater than unbonding period"
            ));
        }

        let trusted_client_state = trusted_light_block.to_sol_client_state(
            trust_level.try_into()?,
            unbonding_period,
            trusting_period,
        )?;
        let trusted_consensus_state = trusted_light_block.to_consensus_state();

        Ok(Self {
            trusted_consensus_state: SolConsensusState::from(trusted_consensus_state).abi_encode(),
            trusted_client_state: trusted_client_state.abi_encode(),
            update_client_vkey: UpdateClientProgram::get_vkey().bytes32(),
            membership_vkey: MembershipProgram::get_vkey().bytes32(),
            uc_and_membership_vkey: UpdateClientAndMembershipProgram::get_vkey().bytes32(),
        })
    }
}

/// Creates the `genesis.json` file for the `SP1ICS07Tendermint` contract.
#[allow(clippy::missing_errors_doc, clippy::missing_panics_doc)]
pub async fn run(args: Args) -> anyhow::Result<()> {
    let tm_rpc_client = HttpClient::from_env();

    let trusted_light_block = tm_rpc_client.get_light_block(args.trusted_block).await?;
    if args.trusted_block.is_none() {
        log::info!(
            "Latest block height: {}",
            trusted_light_block.height().value()
        );
    }

    let genesis = SP1ICS07TendermintGenesis::from_env(
        &trusted_light_block,
        args.trust_options.trusting_period,
        args.trust_options.trust_level,
    )
    .await?;

    std::fs::write(
        PathBuf::from(args.genesis_path),
        serde_json::to_string_pretty(&genesis).unwrap(),
    )
    .unwrap();

    Ok(())
}
