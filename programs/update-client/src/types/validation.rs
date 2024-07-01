//! Contains types and traits for `verify_header` validation within the program.

use ibc_client_tendermint::{
    client_state::ClientState as ClientStateWrapper,
    consensus_state::ConsensusState as ConsensusStateWrapper, types::ConsensusState,
};
use ibc_core_client::context::{ClientValidationContext, ExtClientValidationContext};
use ibc_core_handler_types::error::ContextError;
use ibc_primitives::Timestamp;
use sp1_ics07_tendermint_shared::types::sp1_ics07_tendermint::Env;

/// The client validation context.
pub struct ClientValidationCtx<'a, 'b> {
    env: &'a Env,
    trusted_consensus_state: &'b ConsensusState,
}

impl<'a, 'b> ClientValidationCtx<'a, 'b> {
    /// Create a new instance of the client validation context.
    #[must_use]
    pub const fn new(env: &'a Env, trusted_consensus_state: &'b ConsensusState) -> Self {
        Self {
            env,
            trusted_consensus_state,
        }
    }
}

impl<'a, 'b> ClientValidationContext for ClientValidationCtx<'a, 'b> {
    type ClientStateRef = ClientStateWrapper;
    type ConsensusStateRef = ConsensusStateWrapper;

    fn consensus_state(
        &self,
        _client_cons_state_path: &ibc_core_host_types::path::ClientConsensusStatePath,
    ) -> Result<Self::ConsensusStateRef, ContextError> {
        // This is the trusted consensus state, whether or not it corresponds to the
        // consensus state path will be checked in solidity.
        Ok(self.trusted_consensus_state.clone().into())
    }

    fn client_state(
        &self,
        _client_id: &ibc_core_host_types::identifiers::ClientId,
    ) -> Result<Self::ClientStateRef, ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }

    fn client_update_meta(
        &self,
        _client_id: &ibc_core_host_types::identifiers::ClientId,
        _height: &ibc_core_client::types::Height,
    ) -> Result<(Timestamp, ibc_core_client::types::Height), ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }
}

impl<'a, 'b> ExtClientValidationContext for ClientValidationCtx<'a, 'b> {
    fn host_timestamp(&self) -> Result<Timestamp, ContextError> {
        Ok(Timestamp::from_nanoseconds(self.env.now).unwrap())
    }

    fn host_height(&self) -> Result<ibc_core_client::types::Height, ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }

    fn consensus_state_heights(
        &self,
        _client_id: &ibc_core_host_types::identifiers::ClientId,
    ) -> Result<Vec<ibc_core_client::types::Height>, ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }

    fn next_consensus_state(
        &self,
        _client_id: &ibc_core_host_types::identifiers::ClientId,
        _height: &ibc_core_client::types::Height,
    ) -> Result<Option<Self::ConsensusStateRef>, ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }

    fn prev_consensus_state(
        &self,
        _client_id: &ibc_core_host_types::identifiers::ClientId,
        _height: &ibc_core_client::types::Height,
    ) -> Result<Option<Self::ConsensusStateRef>, ContextError> {
        // not needed by the `verify_header` function
        unimplemented!()
    }
}
