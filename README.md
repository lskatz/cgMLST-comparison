# cgMLST-comparison

Comparing distances for cgMLST

## Methods

1. Survey different cgMLST methods
2. Have an existential crisis that each cgMLST method has a slightly different database that I cannot account for
3. Receive validation datasets from PulseNet (not publicly available)
3. Run cgMLST using each method
4. Create pairwise distances using `distance.*` methods in the lskScripts repo
5. Record
   * number of alleles in common
   * number of loci compared
   * identity = alleles / loci

## Results

1. Found suitable callers
   * EToKi
   * ChewBBACA
2. Created scatter plots with goodness of fit

| dataset | link |
| ---------------- |
| _L. monocytogenes_ | [notebook](lmo/lmo.ipynb) |
| _C. jejuni_ | [notebook](campy/campy.ipynb) |
