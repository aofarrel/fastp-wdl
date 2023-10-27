version 1.0

import "./fastp_tasks.wdl" as fastp_tasks

workflow fastp_one_sample {
    input {
        Array[File] fastq_pair
        Boolean output_cleaned_fastqs = true
    }
    
    call fastp_tasks.fastp_and_parse as fastp_and_parse {
        input:
            fastq_1 = fastq_pair[0],
            fastq_2 = fastq_pair[1],
            output_cleaned_fastqs = output_cleaned_fastqs
    }
    
    output {
        File?  cleaned_fastq1        = fastp_and_parse.very_clean_fastq1
        File?  cleaned_fastq2        = fastp_and_parse.very_clean_fastq2
        File   html_report           = fastp_and_parse.html_report
        File   json_report           = fastp_and_parse.json_report
        Float  out_percent_above_q30 = fastp_and_parse.out_percent_above_q30
        String sample_name           = fastp_and_parse.sample_name
        Int    out_total_reads       = fastp_and_parse.out_total_reads
    }
}