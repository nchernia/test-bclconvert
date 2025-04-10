version 1.0
workflow BclConvertWorkflow {
    
    input {
        String bcl_tar_gcs         # GCS path to tar.gz of BCLs
        String sample_sheet        # Local path or cloud path to sample sheet
        Int? bcl_uncompressed_size_gb   # Estimate of uncompressed BCL size
    }

    call BclConvert {
        input:
            bcl_tar_gcs=bcl_tar_gcs,
            sample_sheet=sample_sheet,
            bcl_uncompressed_size_gb=bcl_uncompressed_size_gb
    }

    output {
        Array[File] fastq_files = BclConvert.fastq_files
    }
}

task BclConvert {
    input {
        File bcl_tar_gcs
        String sample_sheet
		Boolean zipped = true

		# GCS folder where to store the output data
		#String outputDir
    }

    String tar_flags = if zipped then 'ixzf' else 'ixf'
	String untarBcl = 'gsutil -m -o GSUtil:parallel_thread_count=1' +
		                ' -o GSUtil:sliced_object_download_max_components=8' +
		                ' cp "~{bcl}" . && ' +
		                'tar "~{tar_flags}" "~{basename(bcl_tar_gcs)}" --exclude Images --exclude Thumbnail_Images' 
    Float bclSize = size(bcl, 'G')
    Int diskSize = ceil(2.1 * bclSize)
	String diskType = if diskSize > 375 then "SSD" else "LOCAL"

    command <<<
        echo "Downloading BCL tarball from:" ~{bcl_tar_gcs}
        ~{untarBcl}

        echo "Running bcl-convert..."
        bcl-convert \
            --bcl-input-directory bcl_data \
            --output-directory fastq \
            --sample-sheet ~{sample_sheet}
    >>>

    output {
        Array[File] fastq_files = glob("fastq/*fastq.gz")
    }

    runtime {
        docker: "nchernia/bcl-convert:latest"
        cpu: 4
        memory: "16G"
        disks: "local-disk ~{diskSize} ~{diskType}"
    }
}
