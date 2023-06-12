# fastp-wdl
 Partial WDLization of fastp that focuses on the QC reporting aspects of fastp. Currently does not output fastqs -- the idea is that you are using this WDL to get quality information for fastqs that you have already filtered/trimmed/decontaminated.


## What if I want fastp to actually clean up my fastqs?
[Check out Thiagen's version of fastp](https://github.com/theiagen/public_health_viral_genomics/blob/d75e99bd471413ed9315fb31183dcff934d79204/tasks/task_read_clean.wdl#L250).