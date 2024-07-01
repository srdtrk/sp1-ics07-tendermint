use std::env;

use alloy::{
    network::EthereumWallet, providers::ProviderBuilder, signers::local::PrivateKeySigner,
};
use ibc_client_tendermint::types::{ConsensusState, Header};
use ibc_core_client_types::Height as IbcHeight;
use ibc_core_commitment_types::commitment::CommitmentRoot;
use log::{debug, info};
use reqwest::Url;
use sp1_ics07_tendermint_operator::{rpc::TendermintRPCClient, SP1ICS07TendermintProver};
use sp1_ics07_tendermint_shared::types::sp1_ics07_tendermint::{self, Env};
use sp1_sdk::utils::setup_logger;

/// An implementation of a Tendermint Light Client operator that will poll an onchain Tendermint
/// light client and generate a proof of the transition from the latest block in the contract to the
/// latest block on the chain. Then, submits the proof to the contract and updates the contract with
/// the latest block hash and height.
#[tokio::main]
async fn main() -> anyhow::Result<()> {
    dotenv::dotenv().expect("Failed to load .env file");
    setup_logger();

    let rpc_url = env::var("RPC_URL").expect("RPC_URL not set");
    let mut private_key = env::var("PRIVATE_KEY").expect("PRIVATE_KEY not set");
    if let Some(stripped) = private_key.strip_prefix("0x") {
        private_key = stripped.to_string();
    }
    let contract_address = env::var("CONTRACT_ADDRESS").expect("CONTRACT_ADDRESS not set");

    // Instantiate a Tendermint prover based on the environment variable.
    let signer: PrivateKeySigner = private_key.parse()?;
    let wallet = EthereumWallet::from(signer);
    let provider = ProviderBuilder::new()
        .with_recommended_fillers()
        .wallet(wallet)
        .on_http(Url::parse(rpc_url.as_str())?);

    let tendermint_rpc_client = TendermintRPCClient::default();
    let prover = SP1ICS07TendermintProver::new();

    let contract = sp1_ics07_tendermint::new(contract_address.parse()?, provider);

    loop {
        let contract_client_state = contract.getClientState().call().await?._0;

        // Read the existing trusted header hash from the contract.
        let trusted_revision_number = contract_client_state.latest_height.revision_number;
        let trusted_block_height = contract_client_state.latest_height.revision_height;
        if trusted_block_height == 0 {
            panic!(
                "No trusted height found on the contract. Something is wrong with the contract."
            );
        }

        let trusted_light_block = tendermint_rpc_client
            .get_light_block(Some(trusted_block_height))
            .await?;
        let target_light_block = tendermint_rpc_client.get_light_block(None).await?;
        let target_height = target_light_block.height().value();

        // Get trusted consensus state from the contract.
        let trusted_consensus_state = ConsensusState {
            timestamp: trusted_light_block.signed_header.header.time,
            root: CommitmentRoot::from_bytes(
                trusted_light_block.signed_header.header.app_hash.as_bytes(),
            ),
            next_validators_hash: trusted_light_block
                .signed_header
                .header
                .next_validators_hash,
        }
        .into();

        let chain_id = target_light_block.signed_header.header.chain_id.to_string();
        let proposed_header = Header {
            signed_header: target_light_block.signed_header,
            validator_set: target_light_block.validators,
            trusted_height: IbcHeight::new(
                trusted_revision_number.into(),
                trusted_block_height.into(),
            )
            .unwrap(),
            trusted_next_validator_set: trusted_light_block.next_validators,
        };

        let contract_env = Env {
            chain_id,
            trust_threshold: contract_client_state.trust_level,
            trusting_period: contract_client_state.trusting_period,
            now: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos() as u64,
        };

        // Generate a proof of the transition from the trusted block to the target block.
        let proof_data = prover.generate_ics07_update_client_proof(
            &trusted_consensus_state,
            &proposed_header,
            &contract_env,
        );

        // Construct the on-chain call and relay the proof to the contract.
        let proof_as_bytes = hex::decode(&proof_data.proof.encoded_proof).unwrap();

        contract
            .verifyIcs07UpdateClientProof(
                proof_as_bytes.into(),
                proof_data.public_values.to_vec().into(),
            )
            .send()
            .await?
            .watch()
            .await?;

        info!(
            "Updated the ICS-07 Tendermint light client at address {} from block {} to block {}.",
            contract_address, trusted_block_height, target_height
        );

        // Sleep for 60 seconds.
        debug!("sleeping for 60 seconds");
        tokio::time::sleep(std::time::Duration::from_secs(60)).await;
    }
}
