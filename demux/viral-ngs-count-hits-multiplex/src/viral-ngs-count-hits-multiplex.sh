#!/bin/bash

main() {
    set -e -x -o pipefail

    #######################################
    # Prepare input/params for count_hits #
    #######################################
    if [ -z "$out_fn" ]; then
        out_fn="hit_counts.txt"
    fi

    ###################################
    # Prepare input/params for fastqc #
    ###################################
    fastqc_opts=""
    if [ -n "$contaminants_txt" ]; then
        contaminants_txt=$(dx-jobutil-parse-link "$contaminants_txt")
        fastqc_opts="-icontaminants_txt $contaminants_txt $fastqc_opts"
    fi

    if [ -n "$adapters_txt" ]; then
        adapters_txt=$(dx-jobutil-parse-link "$adapters_txt")
        fastqc_opts="-iadapters_txt $adapters_txt $fastqc_opts"
    fi


    if [ -n "$limits_txt" ]; then
        limits_txt=$(dx-jobutil-parse-link "$adapters_txt")
        fastqc_opts="-ilimits_txt $limits_txt $fastqc_opts"
    fi

    if [ -n "$extra_options" ]; then
        fastqc_opts="-iextra_options $extra_options $fastqc_opts"
    fi

    count_hits_applet_id=$(dx-jobutil-parse-link "$count_hits_applet")
    fastqc_applet_id=$(dx-jobutil-parse-link "$fastqc_applet")
    fastqc_job_ids=()

    #########################################
    # Lauch viral-ngs-count-hits and fastqc #
    #########################################
    for i in "${!in_bams[@]}"; do

        bam="${in_bams[$i]}"
        bam_name="${in_bams_prefix[$i]}"
        lane_folder=""
        lane=$(dx describe --json "$bam" | jq -r .properties.lane)
        if [ "$lane" != "null" ]; then
            lane_folder="/lane_$lane"
        fi

        count_hit_job_id=$(dx run $count_hits_applet_id \
        -iin_bam="${bam}" \
        -iper_sample_output="${per_sample_output}" \
        -iref_fasta_tar="${ref_fasta}" \
        -iout_fn="${out_fn}" \
        --name "count_hits $bam_name" \
        ${lane_folder:+--destination "$lane_folder"} \
        $opts --yes --brief)

        fastqc_dest="$lane_folder"
        if [ "$per_sample_output" == "true" ]; then
            fastqc_dest="$fastqc_dest/$bam_name"
        fi

        fastqc_job_id=$(dx run $fastqc_applet_id \
        -ireads="${bam}" \
        -iformat="${format}" -ikmer_size="${kmer_size}" \
        -inogroup="${nogroup}" $fastqc_opts \
        --name "fastqc $bam_name" \
        ${fastqc_dest:+--destination "$fastqc_dest"} \
        --yes --brief)

        fastqc_job_ids+=($fastqc_job_id)

        dx-jobutil-add-output count_files $count_hit_job_id:count_files --class=array:jobref
        dx-jobutil-add-output report_html $fastqc_job_id:report_html --class=array:jobref
        dx-jobutil-add-output stats_txt $fastqc_job_id:stats_txt --class=array:jobref
    done
}
