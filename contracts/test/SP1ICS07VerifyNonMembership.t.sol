// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdError} from "forge-std/StdError.sol";
import {ICS07Tendermint} from "../src/ics07-tendermint/ICS07Tendermint.sol";
import {SP1ICS07Tendermint} from "../src/SP1ICS07Tendermint.sol";
import {SP1ICS07TendermintTest} from "./SP1ICS07TendermintTest.sol";
import {SP1Verifier} from "@sp1-contracts/SP1Verifier.sol";
import {SP1MockVerifier} from "@sp1-contracts/SP1MockVerifier.sol";

struct SP1ICS07VerifyNonMembershipFixtureJson {
    uint32 proofHeight;
    bytes trustedClientState;
    bytes trustedConsensusState;
    bytes32 updateClientVkey;
    bytes32 verifyMembershipVkey;
    bytes32 commitmentRoot;
    bytes publicValues;
    bytes proof;
}

// set constant string
string constant verifyNonMembershipPath = "clients/07-tendermint-001/clientState";

contract SP1ICS07VerifyMembershipTest is SP1ICS07TendermintTest {
    using stdJson for string;

    SP1ICS07VerifyNonMembershipFixtureJson public fixture;
    SP1ICS07VerifyNonMembershipFixtureJson public mockFixture;

    function setUp() public {
        fixture = loadFixture("verify_non_membership_fixture.json");
        mockFixture = loadFixture("mock_verify_non_membership_fixture.json");

        setUpTest(
            "verify_non_membership_fixture.json",
            "mock_verify_non_membership_fixture.json"
        );
    }

    function loadFixture(
        string memory fileName
    ) public view returns (SP1ICS07VerifyNonMembershipFixtureJson memory) {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/fixtures/", fileName);
        string memory json = vm.readFile(path);
        bytes memory trustedClientState = json.readBytes(".trustedClientState");
        bytes memory trustedConsensusState = json.readBytes(
            ".trustedConsensusState"
        );
        uint32 proofHeight = uint32(json.readUint(".proofHeight"));
        bytes32 updateClientVkey = json.readBytes32(".updateClientVkey");
        bytes32 verifyMembershipVkey = json.readBytes32(
            ".verifyMembershipVkey"
        );
        bytes32 commitmentRoot = json.readBytes32(".commitmentRoot");
        bytes memory publicValues = json.readBytes(".publicValues");
        bytes memory proof = json.readBytes(".proof");

        SP1ICS07VerifyNonMembershipFixtureJson
            memory fix = SP1ICS07VerifyNonMembershipFixtureJson({
                commitmentRoot: commitmentRoot,
                trustedClientState: trustedClientState,
                trustedConsensusState: trustedConsensusState,
                proofHeight: proofHeight,
                updateClientVkey: updateClientVkey,
                verifyMembershipVkey: verifyMembershipVkey,
                publicValues: publicValues,
                proof: proof
            });

        return fix;
    }

    // Confirm that submitting a real proof passes the verifier.
    function test_ValidSP1ICS07VerifyNonMembership() public view {
        ics07Tendermint.verifyIcs07VerifyNonMembershipProof(
            fixture.proof,
            fixture.publicValues,
            fixture.proofHeight,
            fixture.trustedConsensusState,
            verifyNonMembershipPath
        );

        // to console
        console.log(
            "VerifyNonMembership gas used: ",
            vm.lastCallGas().gasTotalUsed
        );
    }

    // Confirm that submitting an empty proof passes the mock verifier.
    function test_ValidMockVerifyMembership() public view {
        mockIcs07Tendermint.verifyIcs07VerifyNonMembershipProof(
            mockFixture.proof,
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            verifyNonMembershipPath
        );
    }

    // Confirm that submitting a non-empty proof with the mock verifier fails.
    function test_Invalid_MockVerifyNonMembership() public {
        // Invalid proof
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07VerifyNonMembershipProof(
            bytes("invalid"),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            verifyNonMembershipPath
        );

        // Invalid proof height
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07VerifyNonMembershipProof(
            bytes(""),
            mockFixture.publicValues,
            1,
            mockFixture.trustedConsensusState,
            verifyNonMembershipPath
        );

        // Invalid trusted consensus state
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07VerifyNonMembershipProof(
            bytes(""),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            bytes("invalid"),
            verifyNonMembershipPath
        );
    }

    // Confirm that submitting a random proof with the real verifier fails.
    function test_Invalid_VerifyNonMembership() public {
        vm.expectRevert();
        ics07Tendermint.verifyIcs07VerifyNonMembershipProof(
            bytes("invalid"),
            fixture.publicValues,
            fixture.proofHeight,
            fixture.trustedConsensusState,
            verifyNonMembershipPath
        );
    }
}