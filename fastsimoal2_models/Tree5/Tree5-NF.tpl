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
0
//historical event: time, source, sink, migrants, new size, new growth, migr. matrix
4 historical event
HYBR   1 3 SURF 1 0 0
HYBR   1 0 1 1 0 0
DIV03   0 3 1 A03_RESIZE 0 0
DIV32   3 2 1 ANC_RESIZE 0 0
//Number of independent loci [chromosome] 
1 0
//Per chromosome: Number of contiguous linkage Block: a block is a set of contiguous loci
1
//per Block:data type, number of loci, per generation recombination and mutation rates and optional parameters
FREQ 1 0 5.62e-9 OUTEXP
