version 1.0

import "./fastp_tasks.wdl" as fastp_tasks

workflow fastp_many_samples {
    input {
        Array[Array[File]] fastq_pairs
        Boolean output_cleaned_fastqs = true
    }
    
    scatter(fastq_pair in fastq_pairs) {
        call fastp_tasks.fastp_and_parse as fastp_and_parse {
            input:
                fastq_1 = fastq_pair[0],
                fastq_2 = fastq_pair[1],
                output_cleaned_fastqs = output_cleaned_fastqs
        }
    }
    
    output {
        Array[File?]  cleaned_fastq1s        = fastp_and_parse.very_clean_fastq1
        Array[File?]  cleaned_fastq2s        = fastp_and_parse.very_clean_fastq2
        Array[File]   html_reports           = fastp_and_parse.html_report
        Array[File]   json_reports           = fastp_and_parse.json_report
        Array[Float]  out_percents_above_q30 = fastp_and_parse.out_percent_above_q30
        Array[String] sample_names           = fastp_and_parse.sample_name
        Array[Int]    out_total_reads        = fastp_and_parse.out_total_reads
    }
}