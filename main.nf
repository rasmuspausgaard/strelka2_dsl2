#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.filesPath = '' // Define a parameter for the directory containing the files
params.genome_fasta = '/data/shared/genomes/hg38/GRCh38/GRCh38/GRCh38.primary.fa'
params.runDir = "${launchDir.baseName}"


process strelka2_singularity {
    // Specify tags, labels, and other process settings as needed

    input:

    tuple val(metaNormal), path(normalCram), path(normalCrai), val(metaTumor), path(tumorCram), path(tumorCrai)

    // Add the script to run the Strelka workflow using the inputs
    script:
    """
    singularity run -B /data/shared/programmer/simg/strelka2_2.9.10.sif /tools/strelka2/bin/configureStrelkaSomaticWorkflow.py \
    --normalBam ${normalCram} \
    --tumorBam ${tumorCram} \
    --referenceFasta ${params.genome_fasta} \
    --exome \
    --runDir NF_Strelkatest_singularity

    singularity run -B /data/shared/programmer/simg/strelka2_2.9.10.sif python2 ${params.runDir}/runWorkflow.py -j 10 -m local

    singularity run -B /data/shared/programmer/simg/strelka2_2.9.10.sif python2 NF_Strelkatest_singularity/runWorkflow.py \
    -j 10 \
    -m local
    """
}

workflow {
    
    if (params.filesPath == '') {
        println("No file path provided. Use --filesPath to specify the directory containing the files.")
        return
    }

    // Create channels for CRAM and CRAI files, automatically filtering by 'NORMAL' and 'TUMOR' in the filenames
    normalCram = Channel.fromPath("${params.filesPath}/*NORMAL*.cram")
      .map{ file -> tuple(file.baseName.tokenize('.').get(0), file) }
      //.view()
    normalCrai = Channel.fromPath("${params.filesPath}/*NORMAL*.crai")
      .map{ file -> tuple(file.baseName.tokenize('.').get(0), file) }
      //.view()
    tumorCram = Channel.fromPath("${params.filesPath}/*TUMOR*.cram")
      .map{ file -> tuple(file.baseName.tokenize('.').get(0), file) }
      //.view()
    tumorCrai = Channel.fromPath("${params.filesPath}/*TUMOR*.crai")
      .map{ file -> tuple(file.baseName.tokenize('.').get(0), file) }
      //.view()
   
    normalJoined = normalCram.join(normalCrai, by: 0)//.view()
    tumorJoined = tumorCram.join(tumorCrai, by: 0)//.view()

    // Combine the channels into one
    allJoined = normalJoined.join(tumorJoined, by: 0)//.view()



    // Calling the Strelka2 process with the joined channels
    strelka2_singularity(allJoined)
}


