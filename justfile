# Build riscv elf file using `cargo prove build` command
build-program:
  cd program && cargo prove build
  @echo "ELF created at 'program/elf/riscv32im-succinct-zkvm-elf'"