//! A program that verifies the next block header of a blockchain using an IBC tendermint light
//! client.

#![deny(missing_docs)]
#![deny(clippy::nursery, clippy::pedantic, warnings)]
#![allow(clippy::no_mangle_with_rust_abi)]
// These two lines are necessary for the program to properly compile.
//
// Under the hood, we wrap your main function with some extra code so that it behaves properly
// inside the zkVM.
#![no_main]
sp1_zkvm::entrypoint!(main);

use std::{str::FromStr, time::Duration};

use alloy_sol_types::SolValue;
use ibc_client_tendermint::{
    client_state::verify_header,
    types::{ConsensusState, Header, TENDERMINT_CLIENT_TYPE},
};
use ibc_core_host_types::identifiers::{ChainId, ClientId};
use sp1_ics07_tendermint_shared::types::sp1_ics07_tendermint::{
    self, ConsensusState as SolConsensusState, Env, SP1ICS07TendermintOutput,
};
use sp1_ics07_tendermint_update_client::types;
use tendermint_light_client_verifier::{options::Options, ProdVerifier};

/// The main function of the program.
///
/// # Panics
/// Panics if the verification fails.
pub fn main() {
    let encoded_1 = sp1_zkvm::io::read_vec();
    let encoded_2 = sp1_zkvm::io::read_vec();
    let encoded_3 = sp1_zkvm::io::read_vec();

    // input 1: the trusted consensus state
    let trusted_consensus_state = bincode::deserialize::<SolConsensusState>(&encoded_1)
        .unwrap()
        .into();
    // input 2: the proposed header
    let proposed_header = serde_cbor::from_slice::<Header>(&encoded_2).unwrap();
    // input 3: environment
    let env = bincode::deserialize::<Env>(&encoded_3).unwrap();
    // TODO: find an encoding that works for all the structs above.

    let client_id = ClientId::new(TENDERMINT_CLIENT_TYPE, 0).unwrap();
    let chain_id = ChainId::from_str(&env.chain_id).unwrap();
    let options = Options {
        trust_threshold: env.trust_threshold.clone().into(),
        trusting_period: Duration::from_nanos(env.trusting_period),
        clock_drift: Duration::default(),
    };

    let ctx = types::validation::ClientValidationCtx::new(&env, &trusted_consensus_state);

    verify_header::<_, sha2::Sha256>(
        &ctx,
        &proposed_header,
        &client_id,
        &chain_id,
        &options,
        &ProdVerifier::default(),
    )
    .unwrap();

    let trusted_height = sp1_ics07_tendermint::Height {
        revision_number: proposed_header
            .trusted_height
            .revision_number()
            .try_into()
            .unwrap(),
        revision_height: proposed_header
            .trusted_height
            .revision_height()
            .try_into()
            .unwrap(),
    };
    let new_height = sp1_ics07_tendermint::Height {
        revision_number: proposed_header
            .height()
            .revision_number()
            .try_into()
            .unwrap(),
        revision_height: proposed_header
            .height()
            .revision_height()
            .try_into()
            .unwrap(),
    };
    let new_consensus_state = ConsensusState::from(proposed_header);

    let output = SP1ICS07TendermintOutput {
        trusted_consensus_state: trusted_consensus_state.into(),
        new_consensus_state: new_consensus_state.into(),
        env,
        trusted_height,
        new_height,
    };

    sp1_zkvm::io::commit_slice(&output.abi_encode());
}
