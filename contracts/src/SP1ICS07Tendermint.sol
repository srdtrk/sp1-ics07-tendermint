// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ICS07Tendermint} from "./ics07-tendermint/ICS07Tendermint.sol";
import {ISP1Verifier} from "@sp1-contracts/ISP1Verifier.sol";
import "forge-std/console.sol";

/// @title SP1ICS07Tendermint
/// @author srdtrk
/// @notice This contract implements an ICS07 IBC tendermint light client.
/// @custom:poc This is a proof of concept implementation.
contract SP1ICS07Tendermint {
    /// @notice The verification key for the program.
    bytes32 private immutable ics07UpdateClientProgramVkey;
    /// @notice The SP1 verifier contract.
    ISP1Verifier private immutable verifier;

    /// @notice The ICS07Tendermint client state
    ICS07Tendermint.ClientState public clientState;
    /// @notice The mapping from height to consensus state
    mapping(uint64 => ICS07Tendermint.ConsensusState) private consensusStates;

    /// Allowed clock drift in nanoseconds
    uint64 private constant ALLOWED_SP1_CLOCK_DRIFT = 30_000_000_000_000; // 30000 seconds

    /// @notice The public value output for the sp1 program.
    struct SP1ICS07TendermintOutput {
        /// The trusted consensus state.
        ICS07Tendermint.ConsensusState trusted_consensus_state;
        /// The new consensus state with the verified header.
        ICS07Tendermint.ConsensusState new_consensus_state;
        /// The validation environment.
        Env env;
        /// trusted height
        ICS07Tendermint.Height trusted_height;
        /// new height
        ICS07Tendermint.Height new_height;
    }

    /// @notice The environment output for the sp1 program.
    struct Env {
        /// The chain ID of the chain that the client is tracking.
        bytes chain_id;
        /// Fraction of validator overlap needed to update header
        ICS07Tendermint.TrustThreshold trust_threshold;
        /// Duration of the period since the `LatestTimestamp` during which the
        /// submitted headers are valid for upgrade
        uint64 trusting_period;
        /// Timestamp in nanoseconds
        uint64 now;
    }

    /// @notice The constructor sets the program verification key and the initial client and consensus states.
    /// @param _ics07ProgramVkey The verification key for the program.
    /// @param _verifier The address of the SP1 verifier contract.
    /// @param _clientState The encoded initial client state.
    /// @param _consensusState The encoded initial consensus state.
    constructor(
        bytes32 _ics07ProgramVkey,
        address _verifier,
        bytes memory _clientState,
        bytes memory _consensusState
    ) {
        ics07UpdateClientProgramVkey = _ics07ProgramVkey;
        verifier = ISP1Verifier(_verifier);

        clientState = abi.decode(_clientState, (ICS07Tendermint.ClientState));
        ICS07Tendermint.ConsensusState memory consensusState = abi.decode(
            _consensusState,
            (ICS07Tendermint.ConsensusState)
        );
        consensusStates[
            clientState.latest_height_revision_height
        ] = consensusState;
    }

    /// @notice Returns the client state.
    /// @return The client state.
    function getClientState()
        public
        view
        returns (ICS07Tendermint.ClientState memory) {
        return clientState;
    }

    /// @notice Returns the consensus state at the given revision height.
    /// @param revisionHeight The revision height.
    /// @return The consensus state at the given revision height.
    function getConsensusState(
        uint64 revisionHeight
    ) public view returns (ICS07Tendermint.ConsensusState memory) {
        return consensusStates[revisionHeight];
    }

    /// @notice The entrypoint for verifying the proof.
    /// @dev This function verifies the public values and forwards the proof to the SP1 verifier.
    /// @param proof The encoded proof.
    /// @param publicValues The encoded public values.
    function verifyIcs07UpdateClientProof(
        bytes calldata proof,
        bytes calldata publicValues
    ) external {
        // TODO: Make sure that other checks have been made in the proof verification
        // such as the consensus state not being outside the trusting period.
        verifier.verifyProof(ics07UpdateClientProgramVkey, publicValues, proof);

        SP1ICS07TendermintOutput memory output = abi.decode(publicValues,(SP1ICS07TendermintOutput));

        validatePublicValues(output);

        // adding the new consensus state to the mapping
        consensusStates[output.new_height.revision_height] = output.new_consensus_state;
        clientState.latest_height_revision_height = output.new_height.revision_height;
        clientState.latest_height_revision_number = output.new_height.revision_number;
    }

    /// @notice Validates the SP1ICS07TendermintOutput public values.
    /// @param output The public values.
    function validatePublicValues(
        SP1ICS07TendermintOutput memory output
    ) private view {
        require(
            !clientState.is_frozen,
            "SP1ICS07TM: client is frozen"
        );
        // TODO: Make sure this timestamp check is correct
        require(
            block.timestamp * 1e9 <= output.env.now + ALLOWED_SP1_CLOCK_DRIFT,
            "SP1ICS07TTM: invalid timestamp"
        );
        require(
            keccak256(output.env.chain_id)==
             keccak256(clientState.chain_id),
            "SP1ICS07TM: chain ID mismatch"
        );
        require(
            output.env.trust_threshold.numerator ==
                clientState.trust_level_numerator &&
                output.env.trust_threshold.denominator ==
                clientState.trust_level_denominator,
            "SP1ICS07TM: trust threshold mismatch"
        );
        require(
            output.env.trusting_period == clientState.unbonding_period,
            "SP1ICS07TM: unbonding period mismatch"
        );

        require(consensusStates[output.trusted_height.revision_height].timestamp == output.trusted_consensus_state.timestamp 
        && keccak256(consensusStates[output.trusted_height.revision_height].root) == keccak256(output.trusted_consensus_state.root)
        && keccak256(consensusStates[output.trusted_height.revision_height].next_validators_hash) == keccak256(output.trusted_consensus_state.next_validators_hash),
            "SP1ICS07TM: trusted consensus state mismatch"
        );
        // TODO: Make sure that we don't need more checks.
    }    
}
