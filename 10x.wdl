workflow BclConvertWorkflow {
    input {
        String bcl_tar_gcs         # GCS path to tar.gz of BCLs
        String sample_sheet        # Local path or cloud path to sample sheet
        Int? bcl_uncompressed_size_gb = 200  # Estimate of uncompressed BCL size
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
        String bcl_tar_gcs
        String sample_sheet
        Int bcl_uncompressed_size_gb
    }

command <<<
    set -euxo pipefail

    echo "Downloading BCL tarball from:" ~{bcl_tar_gcs}
    gsutil cp ~{bcl_tar_gcs} bcl_data.tar.gz

    echo "Extracting BCL tarball..."
    mkdir -p bcl_data
    tar -xzf bcl_data.tar.gz -C bcl_data

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
        disks: "local-disk ~{bcl_uncompressed_size_gb} HDD"
    }
}

