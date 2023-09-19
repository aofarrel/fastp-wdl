# fastp-wdl
 Partial WDLization of fastp that focuses on ease-of-use. Outputs fastp's HTML and JSON reports, and optionally parses those reports for specific information. Optionally outputs cleaned fastqs.


## How does this WDL differ from fastp's defaults?

| value                    | WDL  | original | justification                                                                   |
|--------------------------|------|----------|---------------------------------------------------------------------------------|
| disable_adaptor_trimming | true | false    | This WDL assumes your reads have already been through Trimmomatic               |
| disable_trim_poly_g      | true | false    | Alignment with Trimmomatic |
| output_cleaned_fastqs    | true | n/a      | fastp always generates cleaned fastqs; setting this to false allows a user who only cares about QC reports to save delocalization time by reducing the number of outputs |


## I want different features, has someone else WDLized this?
[Check out Thiagen's version of fastp](https://github.com/theiagen/public_health_viral_genomics/blob/d75e99bd471413ed9315fb31183dcff934d79204/tasks/task_read_clean.wdl#L250).


## fastp reference
Chen S, Zhou Y, Chen Y, Gu J. fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics. 2018 Sep 1;34(17):i884-i890. doi: 10.1093/bioinformatics/bty560. PMID: 30423086; PMCID: PMC6129281. <https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6129281/>