version 1.0

workflow fastp_wf {
    input {
        Array[File] fastq_pair
    }
    
    call fastp {
        input:
            fastq_1 = fastq_pair[0],
            fastq_2 = fastq_pair[1]
    }
}

task fastp {
    input {
        File fastq_1
        File fastq_2

        Int average_qual = 30
        Boolean disable_adaptor_trimming = true

        Int cpu = 4
        Int preempt = 1
    }
    String sample_name = sub(basename(fastq_1), "_1", "")
    Int disk_size = 2*ceil(size(fastq_1, "GB")) + 1
    String arg_adaptor_trimming = "--disable_adaptor_trimming" if disable_adaptor_trimming is true else ""

    parameter_meta {
        average_qual: "if one read's average quality score <avg_qual, then this read/pair is discarded. 0 means no requirement"
        disable_adaptor_trimming: "disable trimming adaptors; use this if your reads already went through trimmomatic"
    }

    command <<<
    fastp --in1 "~{fastq_1}" --in2 "~{fastq_2}" \
        --average_qual ~{average_qual} \
        --html "~{sample_name}_fastp.html" --json "~{sample_name}_fastp.json"
    >>>

    runtime {
        cpu: cpu
        disks: "local-disk " + disk_size + " SSD"
        docker: "quay.io/staphb/fastp:0.23.2"
        preemptible: preempt
    }

    output {
        File html_report = glob("*.html")[0]
        File json_report = glob("*.json")[0]
    }

}

#task parse_fastp_output {
#    input {
#        File fastp_report
#    }
#
#    command <<<
#    >>>
#}