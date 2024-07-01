use ibc_client_tendermint::types::Header;
use sp1_ics07_tendermint_shared::types::sp1_ics07_tendermint::{
    ConsensusState as SolConsensusState, Env,
};
use sp1_sdk::{ProverClient, SP1PlonkBn254Proof, SP1ProvingKey, SP1Stdin, SP1VerifyingKey};

pub mod rpc;

// The path to the ELF file for the Succinct zkVM program.
pub const TENDERMINT_ELF: &[u8] = include_bytes!("../../elf/riscv32im-succinct-zkvm-elf");

pub struct SP1ICS07TendermintProver {
    pub prover_client: ProverClient,
    pub pkey: SP1ProvingKey,
    pub vkey: SP1VerifyingKey,
}

impl Default for SP1ICS07TendermintProver {
    fn default() -> Self {
        Self::new()
    }
}

impl SP1ICS07TendermintProver {
    pub fn new() -> Self {
        log::info!("Initializing SP1 ProverClient...");
        let prover_client = ProverClient::new();
        let (pkey, vkey) = prover_client.setup(TENDERMINT_ELF);
        log::info!("SP1 ProverClient initialized");
        Self {
            prover_client,
            pkey,
            vkey,
        }
    }

    /// Generate a proof of an update from trusted_light_block to target_light_block. Returns an
    /// SP1Groth16Proof.
    pub fn generate_ics07_update_client_proof(
        &self,
        trusted_consensus_state: &SolConsensusState,
        proposed_header: &Header,
        contract_env: &Env,
    ) -> SP1PlonkBn254Proof {
        // Encode the inputs into our program.
        // NOTE: We are using SolConsensusState because I'm failing to serialize the
        // ConsensusState struct properly. It always seems modified when deserialized.
        let encoded_1 = bincode::serialize(&trusted_consensus_state).unwrap();
        // NOTE: The Header struct is not deserializable by bincode, so we use CBOR instead.
        let encoded_2 = serde_cbor::to_vec(proposed_header).unwrap();
        let encoded_3 = bincode::serialize(contract_env).unwrap();
        // TODO: find an encoding that works for all the structs above.

        // Write the encoded light blocks to stdin.
        let mut stdin = SP1Stdin::new();
        stdin.write_vec(encoded_1);
        stdin.write_vec(encoded_2);
        stdin.write_vec(encoded_3);

        // Generate the proof. Depending on SP1_PROVER env variable, this may be a mock, local or network proof.
        let proof = self
            .prover_client
            .prove_plonk(&self.pkey, stdin)
            .expect("proving failed");

        // Verify proof.
        self.prover_client
            .verify_plonk(&proof, &self.vkey)
            .expect("Verification failed");

        // Return the proof.
        proof
    }
}
