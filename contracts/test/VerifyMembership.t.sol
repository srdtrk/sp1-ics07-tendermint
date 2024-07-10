// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdError} from "forge-std/StdError.sol";
import {ICS07Tendermint} from "../src/ics07-tendermint/ICS07Tendermint.sol";
import {SP1ICS07Tendermint} from "../src/SP1ICS07Tendermint.sol";
import {MembershipTest} from "./MembershipTest.sol";
import {MembershipProgram} from "../src/ics07-tendermint/MembershipProgram.sol";
import {SP1Verifier} from "@sp1-contracts/SP1Verifier.sol";
import {SP1MockVerifier} from "@sp1-contracts/SP1MockVerifier.sol";

// set constant string
string constant verifyMembershipPath = "clients/07-tendermint-0/clientState";

contract SP1ICS07VerifyMembershipTest is MembershipTest {
    function setUp() public {
        setUpTestWithFixtures(
            "verify_membership_fixture.json",
            "mock_verify_membership_fixture.json"
        );
    }

    function test_ValidateFixtures() public view {
        assertEq(kvPairs().length, 1);
        assertEq(kvPairs()[0].key, verifyMembershipPath);
        assert(kvPairs()[0].value.length != 0);

        assertEq(mockKvPairs().length, 1);
        assertEq(mockKvPairs()[0].key, verifyMembershipPath);
        assert(mockKvPairs()[0].value.length != 0);
    }

    // Confirm that submitting a real proof passes the verifier.
    function test_ValidVerifyMembership() public view {
        bytes32[] memory kvPairHashes = new bytes32[](1);
        bytes32 kvPairHash = keccak256(abi.encode(kvPairs()[0]));
        kvPairHashes[0] = kvPairHash;

        ics07Tendermint.verifyIcs07MembershipProof(
            fixture.proof,
            fixture.publicValues,
            fixture.proofHeight,
            fixture.trustedConsensusState,
            kvPairHashes
        );

        // to console
        console.log(
            "VerifyMembership gas used: ",
            vm.lastCallGas().gasTotalUsed
        );
    }

    // Confirm that submitting an empty proof passes the mock verifier.
    function test_ValidMockVerifyMembership() public view {
        bytes32[] memory kvPairHashes = new bytes32[](1);
        bytes32 kvPairHash = keccak256(abi.encode(mockKvPairs()[0]));
        kvPairHashes[0] = kvPairHash;

        mockIcs07Tendermint.verifyIcs07MembershipProof(
            mockFixture.proof,
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            kvPairHashes
        );
    }

    // Confirm that submitting a non-empty proof with the mock verifier fails.
    function test_Invalid_MockVerifyMembership() public {
        bytes32[] memory kvPairHashes = new bytes32[](1);
        bytes32 kvPairHash = keccak256(abi.encode(mockKvPairs()[0]));
        kvPairHashes[0] = kvPairHash;

        // Invalid proof
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07MembershipProof(
            bytes("invalid"),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            kvPairHashes
        );

        // Invalid proof height
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07MembershipProof(
            bytes(""),
            mockFixture.publicValues,
            1,
            mockFixture.trustedConsensusState,
            kvPairHashes
        );

        // Invalid trusted consensus state
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07MembershipProof(
            bytes(""),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            bytes("invalid"),
            kvPairHashes
        );

        // empty kvPairHashes
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07MembershipProof(
            bytes(""),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            new bytes32[](0)
        );

        // Invalid kvPairHashes
        bytes32[] memory invalidHashes = new bytes32[](1);
        invalidHashes[0] = keccak256("invalid");
        vm.expectRevert();
        mockIcs07Tendermint.verifyIcs07MembershipProof(
            bytes(""),
            mockFixture.publicValues,
            mockFixture.proofHeight,
            mockFixture.trustedConsensusState,
            invalidHashes
        );
    }

    // Confirm that submitting a random proof with the real verifier fails.
    function test_Invalid_VerifyMembership() public {
        bytes32[] memory kvPairHashes = new bytes32[](1);
        bytes32 kvPairHash = keccak256(abi.encode(mockKvPairs()[0]));
        kvPairHashes[0] = kvPairHash;

        vm.expectRevert();
        ics07Tendermint.verifyIcs07MembershipProof(
            bytes("invalid"),
            fixture.publicValues,
            fixture.proofHeight,
            fixture.trustedConsensusState,
            kvPairHashes
        );
    }
}