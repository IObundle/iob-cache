`define N_CYCLES 1//Number of cycles of read-misses during simulation

//Replacement policy parameters
`define N_WAYS 8
`define REP_POLICY 0 // check Replacement Policy

//Linear-Feedback-Shift-Register - Random generator
`define LFSR_IN 5 // input for random-value generator - way-hit

//Replacement Policy
`define LRU       0 // Least Recently Used -- more resources intensive - N*log2(N) bits per cache line - uses shifts and position as a stack
`define LRU_add   1 // Least Recently Used -- Same as LRU but instead of shifts, it used adders and counters. More resources in low number of ways, but less when there are >=16 ways
`define BIT_PLRU  2 // bit-based Pseudo-Least-Recently-Used, a simpler replacement policy than LRU, using a much lower complexity (lower resources) - N bits per cache line
`define TREE_PLRU 3 // tree-based Pseudo-Least-Recently-Used, uses a tree that updates after any way received an hit, and points towards the oposing one. Uses less resources than bit-pseudo-lru - N-1 bits per cache line

`define VCD
