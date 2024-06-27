// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// @title ICS07Tendermint
/// @author srdtrk
/// @notice Defines shared types for ICS07Tendermint implementations.
contract ICS07Tendermint {
    /// @notice Height of the counterparty chain
    struct Height {
        /// Previously known as "epoch"
        uint64 revision_number;
        /// The height of a block
        uint64 revision_height;
    }

    /// Fraction of validator overlap needed to update header
    struct TrustThreshold {
        /// Numerator of the fraction
        uint64 numerator;
        /// Denominator of the fraction
        uint64 denominator;
    }

    /// @notice Defines the ICS07Tendermint ClientState for ibc-lite
    struct ClientState {
        /// Chain ID
        bytes chain_id;
        /// Fraction of validator overlap needed to update header, Numerator of the fraction
        uint64 trust_level_numerator;
        /// Fraction of validator overlap needed to update header, Denominator of the fraction
        uint64 trust_level_denominator;
        /// Latest height the client was updated to, Previously known as "epoch"
        uint64 latest_height_revision_number;
        /// Latest height the client was updated to, The height of a block
        uint64 latest_height_revision_height;
        /// duration of the period since the LatestTimestamp during which the
        /// submitted headers are valid for upgrade
        uint64 trusting_period;
        /// duration of the staking unbonding period
        uint64 unbonding_period;
        /// whether or not client is frozen (due to misbehavior)
        bool is_frozen;
    }

    /// Defines the Tendermint light client's consensus state at some height.
    struct ConsensusState {
        /// timestamp that corresponds to the block height in which the ConsensusState
        /// was stored.
        uint64 timestamp;
        /// commitment root (i.e app hash)
        bytes root;
        /// next validators hash
        bytes next_validators_hash;
    }
}
