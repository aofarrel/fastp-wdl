# fastp-wdl
 Partial WDLization of fastp that focuses on the QC reporting aspects of fastp. Currently does not output fastqs -- the idea is that you are using this WDL to get quality information for fastqs that you have already filtered/trimmed/decontaminated.


## How does this WDL differ from fastp's defaults?
First of all, it should be noted fastp is a very efficient tool, but WDL adds a lot of overhead. If you are running on only a few samples on a cloud backend, you will likely spend more time localizing and delocalizing files than you will actually running fastp.

| value                    | WDL  | original | justification                                                                   |
|--------------------------|------|----------|---------------------------------------------------------------------------------|
| disable_adaptor_trimming | true | false    | This WDL assumes your reads have already been through Trimmomatic               |
| disable_trim_poly_g      | true | false    | Alignment with Trimmomatic (may also prevent issues with TB's high GC content?) |


## I want different features, has someone else WDLized this?
[Check out Thiagen's version of fastp](https://github.com/theiagen/public_health_viral_genomics/blob/d75e99bd471413ed9315fb31183dcff934d79204/tasks/task_read_clean.wdl#L250).


## fastp reference
Chen S, Zhou Y, Chen Y, Gu J. fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics. 2018 Sep 1;34(17):i884-i890. doi: 10.1093/bioinformatics/bty560. PMID: 30423086; PMCID: PMC6129281. <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6129281/>