`define N_CYCLES 4//Number of cycles of read-misses during simulation

//Replacement policy parameters
`define N_WAYS 8
`define REP_POLICY 1 // check Replacement Policy

//Linear-Feedback-Shift-Register - Random generator
`define LFSR_IN 5 // input for random-value generator - way-hit

//Replacement Policy
`define LRU       0 // Least Recently Used -- more resources intensive - N*log2(N) bits per cache line
`define BIT_PLRU  1 // bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define TREE_PLRU 2 // tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line

`define VCD
