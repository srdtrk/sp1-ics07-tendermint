// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdError} from "forge-std/StdError.sol";
import {ICS07Tendermint} from "ibc-lite-shared/ics07-tendermint/ICS07Tendermint.sol";
import {SP1ICS07Tendermint} from "../src/SP1ICS07Tendermint.sol";
import {SP1Verifier} from "@sp1-contracts/SP1Verifier.sol";
import {SP1MockVerifier} from "@sp1-contracts/SP1MockVerifier.sol";

struct SP1ICS07TendermintFixtureJson {
    bytes trustedClientState;
    bytes trustedConsensusState;
    bytes targetConsensusState;
    uint64 targetHeight;
    bytes32 vkey;
    bytes publicValues;
    bytes proof;
}

contract SP1ICS07TendermintTest is Test {
    using stdJson for string;

    SP1ICS07Tendermint public ics07Tendermint;
    SP1ICS07Tendermint public mockIcs07Tendermint;

    function setUp() public {
        SP1ICS07TendermintFixtureJson memory fixture = loadFixture(
            "fixture.json"
        );
        SP1Verifier verifier = new SP1Verifier();
        ics07Tendermint = new SP1ICS07Tendermint(
            fixture.vkey,
            address(verifier),
            fixture.trustedClientState,
            fixture.trustedConsensusState
        );

        SP1ICS07TendermintFixtureJson memory mockFixture = loadFixture(
            "mock_fixture.json"
        );
        SP1MockVerifier mockVerifier = new SP1MockVerifier();
        mockIcs07Tendermint = new SP1ICS07Tendermint(
            mockFixture.vkey,
            address(mockVerifier),
            mockFixture.trustedClientState,
            mockFixture.trustedConsensusState
        );

        (
            string memory chain_id,
            ICS07Tendermint.TrustThreshold memory trust_level,
            ICS07Tendermint.Height memory latest_height,
            uint64 trusting_period,
            uint64 unbonding_period,
            bool is_frozen
        ) = mockIcs07Tendermint.clientState();

        assert(keccak256(bytes(chain_id)) == keccak256(bytes("mocha-4")));
        assert(trust_level.numerator == 1);
        assert(trust_level.denominator == 3);
        assert(latest_height.revision_number == 4);
        assert(latest_height.revision_height == 2110658);
        assert(trusting_period == 1_209_600_000_000_000);
        assert(unbonding_period == 1_209_600_000_000_000);
        assert(is_frozen == false);

        (
            uint64 timestamp,
            bytes memory root,
            bytes memory next_validators_hash
        ) = mockIcs07Tendermint.consensusStates(2110658);

        assert(timestamp > 0);
        assert(root.length > 0);
        assert(next_validators_hash.length > 0);
    }

    function loadFixture(
        string memory fileName
    ) public view returns (SP1ICS07TendermintFixtureJson memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/fixtures/", fileName);
        string memory json = vm.readFile(path);
        bytes memory trustedClientState = json.readBytes(".trustedClientState");
        bytes memory trustedConsensusState = json.readBytes(
            ".trustedConsensusState"
        );
        bytes memory targetConsensusState = json.readBytes(
            ".targetConsensusState"
        );
        uint64 targetHeight = uint64(json.readUint(".targetHeight"));
        bytes32 vkey = json.readBytes32(".vkey");
        bytes memory publicValues = json.readBytes(".publicValues");
        bytes memory proof = json.readBytes(".proof");

        SP1ICS07TendermintFixtureJson
            memory fixture = SP1ICS07TendermintFixtureJson({
                trustedClientState: trustedClientState,
                trustedConsensusState: trustedConsensusState,
                targetConsensusState: targetConsensusState,
                targetHeight: targetHeight,
                vkey: vkey,
                publicValues: publicValues,
                proof: proof
            });

        return fixture;
    }

    // Confirm that submitting a real proof passes the verifier.
    function test_ValidSP1ICS07Tendermint() public {
        SP1ICS07TendermintFixtureJson memory fixture = loadFixture(
            "fixture.json"
        );

        ics07Tendermint.verifyIcs07UpdateClientProof(
            fixture.proof,
            fixture.publicValues
        );

        (
            string memory chain_id,
            ICS07Tendermint.TrustThreshold memory trust_level,
            ICS07Tendermint.Height memory latest_height,
            uint64 trusting_period,
            uint64 unbonding_period,
            bool is_frozen
        ) = ics07Tendermint.clientState();

        assert(keccak256(bytes(chain_id)) == keccak256(bytes("mocha-4")));
        assert(trust_level.numerator == 1);
        assert(trust_level.denominator == 3);
        assert(latest_height.revision_number == 4);
        assert(latest_height.revision_height == 2110668);
        assert(trusting_period == 1_209_600_000_000_000);
        assert(unbonding_period == 1_209_600_000_000_000);
        assert(is_frozen == false);

        (
            uint64 timestamp,
            bytes memory root,
            bytes memory next_validators_hash
        ) = ics07Tendermint.consensusStates(2110668);

        assert(timestamp > 0);
        assert(root.length > 0);
        assert(next_validators_hash.length > 0);
    }

    // Confirm that submitting an empty proof passes the mock verifier.
    function test_ValidMockTendermint() public {
        SP1ICS07TendermintFixtureJson memory fixture = loadFixture(
            "mock_fixture.json"
        );

        mockIcs07Tendermint.verifyIcs07UpdateClientProof(
            bytes(""),
            fixture.publicValues
        );

        (
            string memory chain_id,
            ICS07Tendermint.TrustThreshold memory trust_level,
            ICS07Tendermint.Height memory latest_height,
            uint64 trusting_period,
            uint64 unbonding_period,
            bool is_frozen
        ) = mockIcs07Tendermint.clientState();

        assert(keccak256(bytes(chain_id)) == keccak256(bytes("mocha-4")));
        assert(trust_level.numerator == 1);
        assert(trust_level.denominator == 3);
        assert(latest_height.revision_number == 4);
        assert(latest_height.revision_height == 2110668);
        assert(trusting_period == 1_209_600_000_000_000);
        assert(unbonding_period == 1_209_600_000_000_000);
        assert(is_frozen == false);

        (
            uint64 timestamp,
            bytes memory root,
            bytes memory next_validators_hash
        ) = mockIcs07Tendermint.consensusStates(2110668);

        assert(timestamp > 0);
        assert(root.length > 0);
        assert(next_validators_hash.length > 0);
    }

    // Confirm that submitting a non-empty proof with the mock verifier fails.
    function test_Invalid_MockTendermint() public {
        SP1ICS07TendermintFixtureJson memory fixture = loadFixture(
            "mock_fixture.json"
        );

        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07UpdateClientProof(
            bytes("invalid"),
            fixture.publicValues
        );
    }

    // Confirm that submitting a random proof with the real verifier fails.
    function test_Invalid_SP1ICS07Tendermint() public {
        SP1ICS07TendermintFixtureJson memory fixture = loadFixture(
            "fixture.json"
        );

        vm.expectRevert();
        ics07Tendermint.verifyIcs07UpdateClientProof(
            bytes("invalid"),
            fixture.publicValues
        );
    }
}
