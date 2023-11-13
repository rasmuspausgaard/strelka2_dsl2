#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

date = new Date().format('yyMMdd')
user = "$USER"
runID = "${date}.${user}"

// input variables
params.normalCram           =null 
params.normalCrai           =null
params.tumorCram            =null 
params.tumorCrai            =null

// Genome variables
params.hg38v1               =null  // primary hg38 full, original hg38 assembly, no decoys, etc.
params.hg38v2               =null  // UCSC NGS set
params.hg38v3               =null  // DEFAULT: NGC version, masked regions. 

// Global variables
launchDir                   = workflow.launchDir
syspath                     = "/data/shared" // Adjust this as necessary for your environment
simgpath                    = "/data/shared/programmer/simg"
params.outdir               ="${launchDir.baseName}.NF_Strelkatest_singularity"
params.runDir               ="${launchDir.baseName}"




// standard server and switching 
params.server               ="lnx01"

switch (params.server) {
    case 'lnx01':
        modules_dir="/home/mmaj/scripts_lnx01/nextflow_lnx01/dsl2/modules";
        subworkflow_dir="/home/mmaj/scripts_lnx01/nextflow_lnx01/dsl2/subworkflows";
    break;
    case 'kga01':
        modules_dir="/home/mmaj/LNX01_mmaj/scripts_lnx01/nextflow_lnx01/dsl2/modules";
        subworkflow_dir="/home/mmaj/LNX01_mmaj/scripts_lnx01/nextflow_lnx01/dsl2/subworkflows";
    break;
}


// standard genome and switching 
params.genome               ="hg38"

switch (params.genome) {
    case 'hg19':
        modules_dir="/home/mmaj/scripts_lnx01/nextflow_lnx01/dsl2/modules";
        subworkflow_dir="/home/mmaj/scripts_lnx01/nextflow_lnx01/dsl2/subworkflows";
    break;
    case 'hg38':
        modules_dir="/home/mmaj/LNX01_mmaj/scripts_lnx01/nextflow_lnx01/dsl2/modules";
        subworkflow_dir="/home/mmaj/LNX01_mmaj/scripts_lnx01/nextflow_lnx01/dsl2/subworkflows";
    break;
}




// Process to join CRAM and CRAI files
process JoinCramCrai {
    input:
    val meta
    path cram
    path crai

    output:
    tuple val(meta), path(cram), path(crai) into joinedCramCrai

    script:
    """
    echo "Joining ${cram} and ${crai}"
    """
}

// Process for running Strelka workflow
process RunStrelka {
    input:
    tuple val(meta), path(normal_cram), path(normal_index)
    tuple val(meta), path(tumor_cram), path(tumor_index)

    output:
    path "${params.runDir}/*"

    script:
    """
    singularity run -B ${s_bind} ${simgpath}/strelka2_2.9.10.sif /tools/strelka2/bin/configureStrelkaSomaticWorkflow.py \
    --normalBam ${normal_cram} \
    --tumorBam ${tumor_cram} \
    --referenceFasta ${genome_fasta} \
    --exome \
    --runDir ${params.runDir}

    singularity run -B /data/shared/programmer/simg/strelka2_2.9.10.sif python2 ${params.runDir}/runWorkflow.py -j 10 -m local
    """
}

// Main workflow
workflow {
    // Channel creation for CRAM and CRAI files
    normalCramChannel = Channel.fromPath(params.normal_cram).map { tuple(it.baseName.tokenize('.').get(0), it) }
    normalCraiChannel = Channel.fromPath(params.normal_Crai).map { tuple(it.baseName.tokenize('.').get(0), it) }
    tumorCramChannel = Channel.fromPath(params.tumor_Cram).map { tuple(it.baseName.tokenize('.').get(0), it) }
    tumorCraiChannel = Channel.fromPath(params.tumor_Crai).map { tuple(it.baseName.tokenize('.').get(0), it) }

    // Joining CRAM and CRAI files
    normalJoined = normalCramChannel.combine(normalCraiChannel)
    tumorJoined = tumorCramChannel.combine(tumorCraiChannel)

    // Running Strelka workflow
    RunStrelka(normalJoined, tumorJoined)
}
