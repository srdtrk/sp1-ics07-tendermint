// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdError} from "forge-std/StdError.sol";
import {ICS07Tendermint} from "../src/ics07-tendermint/ICS07Tendermint.sol";
import {SP1ICS07Tendermint} from "../src/SP1ICS07Tendermint.sol";
import {SP1Verifier} from "@sp1-contracts/SP1Verifier.sol";
import {SP1MockVerifier} from "@sp1-contracts/SP1MockVerifier.sol";

struct SP1ICS07TendermintFixtureJson {
    bytes trustedClientState;
    bytes trustedConsensusState;
    bytes targetConsensusState;
    uint32 targetHeight;
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

        ICS07Tendermint.ConsensusState memory trustedConsensusState = abi
            .decode(
                fixture.trustedConsensusState,
                (ICS07Tendermint.ConsensusState)
            );

        bytes32 trustedConsensusHash = keccak256(
            abi.encode(trustedConsensusState)
        );

        SP1Verifier verifier = new SP1Verifier();
        ics07Tendermint = new SP1ICS07Tendermint(
            fixture.vkey,
            address(verifier),
            fixture.trustedClientState,
            trustedConsensusHash
        );

        // Mock ICS07Tendermint
        SP1ICS07TendermintFixtureJson memory mockFixture = loadFixture(
            "mock_fixture.json"
        );

        ICS07Tendermint.ConsensusState memory mockTrustedConsensusState = abi
            .decode(
                mockFixture.trustedConsensusState,
                (ICS07Tendermint.ConsensusState)
            );

        bytes32 mockTrustedConsensusHash = keccak256(
            abi.encode(mockTrustedConsensusState)
        );

        SP1MockVerifier mockVerifier = new SP1MockVerifier();
        mockIcs07Tendermint = new SP1ICS07Tendermint(
            mockFixture.vkey,
            address(mockVerifier),
            mockFixture.trustedClientState,
            mockTrustedConsensusHash
        );

        ICS07Tendermint.ClientState memory clientState = mockIcs07Tendermint
            .getClientState();
        assert(
            keccak256(bytes(clientState.chain_id)) ==
                keccak256(bytes("mocha-4"))
        );
        assert(clientState.trust_level.numerator == 1);
        assert(clientState.trust_level.denominator == 3);
        assert(clientState.latest_height.revision_number == 4);
        assert(clientState.latest_height.revision_height == 2110658);
        assert(clientState.trusting_period == 1_209_600_000_000_000);
        assert(clientState.unbonding_period == 1_209_600_000_000_000);
        assert(clientState.is_frozen == false);

        bytes32 consensusHash = mockIcs07Tendermint.getConsensusState(2110658);
        assert(consensusHash == trustedConsensusHash);
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
        uint32 targetHeight = uint32(json.readUint(".targetHeight"));
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

        ICS07Tendermint.ClientState memory clientState = ics07Tendermint
            .getClientState();
        assert(
            keccak256(bytes(clientState.chain_id)) ==
                keccak256(bytes("mocha-4"))
        );
        assert(clientState.trust_level.numerator == 1);
        assert(clientState.trust_level.denominator == 3);
        assert(clientState.latest_height.revision_number == 4);
        assert(clientState.latest_height.revision_height == 2110668);
        assert(clientState.trusting_period == 1_209_600_000_000_000);
        assert(clientState.unbonding_period == 1_209_600_000_000_000);
        assert(clientState.is_frozen == false);

        bytes32 consensusHash = ics07Tendermint.getConsensusState(2110668);
        ICS07Tendermint.ConsensusState memory expConsensusState = abi.decode(
            fixture.targetConsensusState,
            (ICS07Tendermint.ConsensusState)
        );
        assert(consensusHash == keccak256(abi.encode(expConsensusState)));
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

        ICS07Tendermint.ClientState memory clientState = mockIcs07Tendermint
            .getClientState();
        assert(
            keccak256(bytes(clientState.chain_id)) ==
                keccak256(bytes("mocha-4"))
        );
        assert(clientState.trust_level.numerator == 1);
        assert(clientState.trust_level.denominator == 3);
        assert(clientState.latest_height.revision_number == 4);
        assert(clientState.latest_height.revision_height == 2110668);
        assert(clientState.trusting_period == 1_209_600_000_000_000);
        assert(clientState.unbonding_period == 1_209_600_000_000_000);
        assert(clientState.is_frozen == false);

        bytes32 consensusHash = mockIcs07Tendermint.getConsensusState(2110668);
        ICS07Tendermint.ConsensusState memory expConsensusState = abi.decode(
            fixture.targetConsensusState,
            (ICS07Tendermint.ConsensusState)
        );
        assert(consensusHash == keccak256(abi.encode(expConsensusState)));
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
