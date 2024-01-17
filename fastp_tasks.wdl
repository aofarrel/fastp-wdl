version 1.0

task fastp_simple {
	input {
		File fastq_1
		File fastq_2

		Int average_qual = 30
		Boolean disable_adaptor_trimming = true
		Boolean output_cleaned_fastqs = true

		Int cpu = 4
		Int preempt = 1
	}
	Int disk_size = 6
	
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
		~{true="--disable_adapter_trimming" false="" disable_adaptor_trimming} \
		--html "~{sample_name}_fastp.html" --json "~{sample_name}_fastp.json"
	
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
	Int disk_size = 6
	
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
		~{true="--disable_adapter_trimming" false="" disable_adaptor_trimming} \
		--html "~{sample}_fastp.html" --json "~{sample}_fastp.json" 
	
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
		File   short_report= glob("*_fastp.txt")[0] # if !(output_cleaned_fastqs) this only has the before filtering info
		
		String sample_name           = sample
		Float  in_percent_above_q20  = read_float("q20_in.txt")
		Float  in_percent_above_q30  = read_float("q30_in.txt")
		Int    in_total_reads        = read_int("reads_in.txt")
		Float  out_percent_above_q20 = if output_cleaned_fastqs then read_float("q20_out.txt") else read_float("q20_in.txt")
		Float  out_percent_above_q30 = if output_cleaned_fastqs then read_float("q30_out.txt") else read_float("q30_in.txt")
		Int    out_total_reads       = if output_cleaned_fastqs then read_int("reads_out.txt") else read_int("reads_in.txt")
		
		File?  very_clean_fastq1 = sample + "_fastp_1.fq"
		File?  very_clean_fastq2 = sample + "_fastp_2.fq"
		
	}

}

task merge_then_fastp {
	input {
		Array[File] reads_files

		Int average_qual = 30
		Boolean disable_adaptor_trimming = false
		Boolean detect_adapter_for_pe = true

		Int cpu = 4
		Int preempt = 1
	}
	Int disk_size = 6
	
	# This needs to be to handle inputs like sample+run+num (ERS457530_ERR551697_1.fastq)
	# or inputs like sample+num (ERS457530_1.fastq). In both cases, we want to convert to just
	# sample name (ERS457530).
	String read_file_basename = basename(reads_files[0]) # used to calculate sample name + outfile_sam
	String sample_name = sub(sub(read_file_basename, "_.*", ""), ".gz", "")

	parameter_meta {
		average_qual: "if one read's average quality score <avg_qual, then this read/pair is discarded. 0 means no requirement"
		disable_adaptor_trimming: "disable trimming adaptors; use this if your reads already went through trimmomatic"
		detect_adapter_for_pe: "detect adapter sequence for PE reads"
	}

	command <<<
	# shellcheck disable=SC2207
	# ^ I tried to get this working with mapfile but the non-mapfile solution seems to be most consistent
	fx_echo_array () {
		fq_array=("$@")
		for fq in "${fq_array[@]}"; do echo "$fq"; done
		printf "\n"
	}
	
	fx_move_to_workdir () { 
		fq_array=("$@")
		for fq in "${fq_array[@]}"; do mv "$fq" .; done 
	}
	
	fx_sort_array () {
		fq_array=("$@")
		readarray -t OUTPUT < <(for fq in "${fq_array[@]}"; do echo "$fq"; done | sort)
		echo "${OUTPUT[@]}" # this is a bit dangerous
	}
	
	fx_echo_array "Inputs as passed in:" "${READS_FILES_RAW[@]}"
	for fq in "${READS_FILES_RAW[@]}"; do mv "$fq" .; done 
	# I really did try to make these next three lines just one -iregex string but
	# kept messing up the syntax -- this approach is unsatisfying but cleaner
	readarray -d '' -t FQ < <(find . -iname "*.fq*" -print0) 
	readarray -d '' FASTQ < <(find . -iname "*.fastq*" -print0)
	readarray -d ' ' -t READS_FILES_UNSORTED < <(echo "${FQ[@]}" "${FASTQ[@]}")
	fx_echo_array "Located files:" "${READS_FILES_UNSORTED[@]}"
	READS_FILES=( $(fx_sort_array "${READS_FILES_UNSORTED[@]}") ) # this appears to be more consistent than mapfile
	fx_echo_array "In workdir and sorted:" "${READS_FILES[@]}"
	
	if (( "${#READS_FILES[@]}" != 2 ))
	then
		# check for gzipped inputs
		some_base=$(basename -- "${READS_FILES[0]}") # just check the first element; should never be a mix of gzipped and not-gzipped fqs
		some_extension="${some_base##*.}"
		if [[ $some_extension = ".gz" ]]
		then
			for fq in "${READS_FILES[@]}"; do gz -d "$fq"; done
			# TODO: check that .gz originals got deleted to avoid issues with find
			readarray -d '' FQ < <(find . -iname "*.fq*" -print0) 
			readarray -d '' FASTQ < <(find . -iname "*.fastq*" -print0)
			readarray -d ' ' READS_FILES_UNZIPPED_UNSORTED < <(echo "${FQ[@]}" "${FASTQ[@]}") 
			READS_FILES=( $(fx_sort_array "${READS_FILES_UNZIPPED_UNSORTED[@]}") )  # this appears to be more consistent than mapfile
			fx_echo_array "After decompressing:" "${READS_FILES[@]}"
		fi
	
		readarray -d '' READ1_LANES_IF_CDPH < <(find . -name "*_R1*" -print0)
		readarray -d '' READ2_LANES_IF_CDPH < <(find . -name "*_R2*" -print0)
		readarray -d '' READ1_LANES_IF_SRA < <(find . -name "*_1.f*" -print0)
		readarray -d '' READ2_LANES_IF_SRA < <(find . -name "*_2.f*" -print0)
		readarray -d ' ' READ1_LANES_UNSORTED < <(echo "${READ1_LANES_IF_CDPH[@]}" "${READ1_LANES_IF_SRA[@]}")
		readarray -d ' ' READ2_LANES_UNSORTED < <(echo "${READ2_LANES_IF_CDPH[@]}" "${READ2_LANES_IF_SRA[@]}")
		READ1_LANES=( $(fx_sort_array "${READ1_LANES_UNSORTED[@]}") )  # this appears to be more consistent than mapfile
		READ2_LANES=( $(fx_sort_array "${READ2_LANES_UNSORTED[@]}") )  # this appears to be more consistent than mapfile
		touch "~{sample_name}_cat_R1.fq"
		touch "~{sample_name}_cat_R2.fq"
		fx_echo_array "Read 1:" "${READ1_LANES[@]}"
		fx_echo_array "Read 2:" "${READ2_LANES[@]}"
		for fq in "${READ1_LANES[@]}"; do cat "$fq" ~{sample_name}_cat_R1.fq > temp; mv temp ~{sample_name}_cat_R1.fq; done
		for fq in "${READ2_LANES[@]}"; do cat "$fq" ~{sample_name}_cat_R2.fq > temp; mv temp ~{sample_name}_cat_R2.fq; done
		
		READS_FILES=( "~{sample_name}_cat_R1.fq" "~{sample_name}_cat_R2.fq" )
		fx_echo_array "After merging:" "${READS_FILES[@]}"
	fi
	
	fastp --in1 "${READS_FILES[0]}" --in2 "${READS_FILES[1]}" \
		--out1 "~{sample_name}_fastp_1.fq" --out2 "~{sample_name}_fastp_2.fq" \
		--average_qual ~{average_qual} \
		~{true="--detect_adapter_for_pe" false="" detect_adapter_for_pe} \
		~{true="--disable_adapter_trimming" false="" disable_adaptor_trimming} \
		--json "~{sample_name}_fastp.json" --html "~{sample_name}_fastp.html"
	
	# parse fastp outputs from JSON
	python3 << CODE
	import os
	import json
	with open("~{sample_name}_fastp.json", "r") as fastpJSON:
		fastp = json.load(fastpJSON)
	with open("~{sample_name}_fastp.txt", "w") as outfile:
		for keys, values in fastp["summary"]["before_filtering"].items():
			outfile.write(f"{keys}\t{values}\n")
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
		File   short_report= glob("*_fastp.txt")[0]
		
		Float  in_percent_above_q20  = read_float("q20_in.txt")
		Float  in_percent_above_q30  = read_float("q30_in.txt")
		Int    in_total_reads        = read_int("reads_in.txt")
		Float  out_percent_above_q20 = read_float("q20_out.txt")
		Float  out_percent_above_q30 = read_float("q30_out.txt")
		Int    out_total_reads       = read_int("reads_out.txt")
		
		File  very_clean_fastq1 = sample_name + "_fastp_1.fq"
		File  very_clean_fastq2 = sample_name + "_fastp_2.fq"
		
	}
}
