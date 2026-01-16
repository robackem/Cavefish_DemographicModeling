//Parameters for the coalescence simulation program : fastsimcoal.exe
4 samples to simulate :
//Population effective sizes (haploid)
N_CMC
N_CME
N_CMS
N_GHOST
//Haploid samples sizes 
38
34
12
0
//Growth rates: negative growth implies population expansion
0
0
0
0
//Number of migration matrices
2
//Migration matrix 0
0 MIG_E2C 0 MIG_G2C
MIG_C2E 0 0 MIG_G2E
0 0 0 0
0 0 0 0
//Migration matrix 1
0 0 0 0
0 0 0 0
0 0 0 0
0 0 0 0
//historical event: time, source, sink, migrants, new size, new growth, migr. matrix
3 historical event
DIV13   1 3 1 A13_RESIZE 0 1
DIV03   0 3 1 A03_RESIZE 0 1
DIV32   3 2 1 ANC_RESIZE 0 1
//Number of independent loci [chromosome] 
1 0
//Per chromosome: Number of contiguous linkage Block: a block is a set of contiguous loci
1
//per Block:data type, number of loci, per generation recombination and mutation rates and optional parameters
FREQ 1 0 5.62e-9 OUTEXP
