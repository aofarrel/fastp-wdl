version 1.0

task fastp {
    input {
        File fastq_1
        File fastq_2

        Int average_qual = 30
        Boolean disable_adaptor_trimming = true
        Boolean output_cleaned_fastqs = true

        Int cpu = 4
        Int preempt = 1
    }
    Int disk_size = 2*ceil(size(fastq_1, "GB")) + 1
    String arg_adapter_trimming = if(disable_adaptor_trimming) then "--disable_adapter_trimming" else ""
    
    # This needs to be to handle inputs like sample+run+num (ERS457530_ERR551697_1.fastq)
    # or inputs like sample+num (ERS457530_1.fastq). In both cases, we want to convert to just
	# sample name (ERS457530).
	String read_file_basename = basename(fastq_1)
	String sample_name = sub(read_file_basename, "_.*", "")

    parameter_meta {
        average_qual: "if one read's average quality score <avg_qual, then this read/pair is discarded. 0 means no requirement"
        disable_adaptor_trimming: "disable trimming adaptors; use this if your reads already went through trimmomatic"
        output_cleaned_fastqs: "[WDL only] if true, output fastps' cleaned fastqs as task-level outputs"
    }

    command <<<
    fastp --in1 "~{fastq_1}" --in2 "~{fastq_2}" --out1 "~{sample_name}_fastp_1.fq" --out2 "~{sample_name}_fastp_2.fq" \
        --average_qual ~{average_qual} \
        --html "~{sample_name}_fastp.html" --json "~{sample_name}_fastp.json" "~{arg_adapter_trimming}"
    
    # delete fastp cleaned fastqs if we dont want them to save on delocalization time
    if [ "~{output_cleaned_fastqs}" == "false" ]
    then
        rm "~{sample_name}_fastp_1.fq"
        rm "~{sample_name}_fastp_2.fq"
    fi
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
        File? very_clean_fastq1 = sample_name + "_fastp_1.fq"
        File? very_clean_fastq2 = sample_name + "_fastp_2.fq"
    }

}

task fastp_and_parse {
    input {
        File fastq_1
        File fastq_2

        Int average_qual = 30
        Boolean disable_adaptor_trimming = true
        Boolean output_cleaned_fastqs = true

        Int cpu = 4
        Int preempt = 1
    }
    Int disk_size = 2*ceil(size(fastq_1, "GB")) + 1
    String arg_adapter_trimming = if(disable_adaptor_trimming) then "--disable_adapter_trimming" else ""
    
    # This needs to be to handle inputs like sample+run+num (ERS457530_ERR551697_1.fastq)
    # or inputs like sample+num (ERS457530_1.fastq). In both cases, we want to convert to just
	# sample name (ERS457530).
	String read_file_basename = basename(fastq_1)
	String sample = sub(read_file_basename, "_.*", "")

    parameter_meta {
        average_qual: "if one read's average quality score <avg_qual, then this read/pair is discarded. 0 means no requirement"
        disable_adaptor_trimming: "disable trimming adaptors; use this if your reads already went through trimmomatic"
        output_cleaned_fastqs: "[WDL only] if true, output fastps' cleaned fastqs as task-level outputs"
    }

    command <<<
    fastp --in1 "~{fastq_1}" --in2 "~{fastq_2}" --out1 "~{sample}_fastp_1.fq" --out2 "~{sample}_fastp_2.fq" \
        --average_qual ~{average_qual} \
        --html "~{sample}_fastp.html" --json "~{sample}_fastp.json" "~{arg_adapter_trimming}"
    
    # parse fastp outputs from JSON
    python3 << CODE
    import os
    import json
    with open("~{sample}_fastp.json", "r") as fastpJSON:
        fastp = json.load(fastpJSON)
    with open("~{sample}_fastp.txt", "w") as outfile:
        for keys, values in fastp["summary"]["before_filtering"].items():
            outfile.write(f"{keys}\t{values}\n")
        if "~{output_cleaned_fastqs}" == "true":
            outfile.write("after fastp cleaned the fastqs:\n")
            for keys, values in fastp["summary"]["after_filtering"].items():
                outfile.write(f"{keys}\t{values}\n")
        else:
            outfile.write("fastp cleaning was skipped, so the above represent the final result of these fastqs.")
    with open("q20_in.txt", "w") as q20_in: q20_in.write(str(fastp["summary"]["before_filtering"]["q20_rate"]))
    with open("q20_out.txt", "w") as q20_out: q20_out.write(str(fastp["summary"]["after_filtering"]["q20_rate"]))
    with open("q30_in.txt", "w") as q30_in: q30_in.write(str(fastp["summary"]["before_filtering"]["q30_rate"]))
    with open("q30_out.txt", "w") as q30_out: q30_out.write(str(fastp["summary"]["after_filtering"]["q30_rate"]))
    with open("reads_in.txt", "w") as reads_in: reads_in.write(str(fastp["summary"]["before_filtering"]["total_reads"])) 
    with open("reads_out.txt", "w") as reads_out: reads_out.write(str(fastp["summary"]["after_filtering"]["total_reads"]))
    
    # delete fastp cleaned fastqs if we dont want them to save on delocalization time
    if "~{output_cleaned_fastqs}" == "false":
        os.remove("~{sample}_fastp_1.fq")
        os.remove("~{sample}_fastp_2.fq")
    
    CODE
    >>>

    runtime {
        cpu: cpu
        disks: "local-disk " + disk_size + " SSD"
        docker: "ashedpotatoes/tbfastprofiler:0.0.1"
        preemptible: preempt
    }

    output {
        File   html_report = glob("*.html")[0]
        File   json_report = glob("*.json")[0]
        File   short_report= glob("*_fastp.txt")[0] # BEFORE filtering
        
        String sample_name       = sample
        Float  in_percent_above_q20 = read_float("q20_in.txt")
        Float  in_percent_above_q30 = read_float("q30_in.txt")
        Int    in_total_reads       = read_int("reads_in.txt")
        Float  out_percent_above_q20 = if output_cleaned_fastqs then read_float("q20_out.txt") else read_float("q20_in.txt")
        Float  out_percent_above_q30 = if output_cleaned_fastqs then read_float("q30_out.txt") else read_float("q30_in.txt")
        Int    out_total_reads       = if output_cleaned_fastqs then read_int("reads_out.txt") else read_int("reads_in.txt")
        
        File?  very_clean_fastq1 = sample + "_fastp_1.fq"
        File?  very_clean_fastq2 = sample + "_fastp_2.fq"
        
    }

}