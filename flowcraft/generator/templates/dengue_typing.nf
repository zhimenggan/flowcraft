
getRef = params.reference ? "true" : "false"
getRef_{{ pid }} = Channel.value(getRef)

process dengue_typing_{{ pid }} {

    // Send POST request to platform
    {% include "post.txt" ignore missing %}

    tag { sample_id }
    errorStrategy "ignore"
    publishDir "results/dengue_typing/${sample_id}/"

    input:
    set sample_id, file(assembly) from {{ input_channel }}
    val ref from getRef_{{ pid }}

    output:
    file "seq_typing*"
    file "*.fa" into _ref_seqTyping, optional True
    {% with task_name="dengue_typing" %}
    {%- include "compiler_channels.txt" ignore missing -%}
    {% endwith %}

    script:
    """
    {
        # Prevents read-only issues
        mkdir rematch_temp
        cp -r /NGStools/ReMatCh rematch_temp
        export PATH="\$(pwd)/rematch_temp/ReMatCh:\$PATH"

        seq_typing.py assembly --org Dengue Virus -f ${assembly} -o ./ -j $task.cpus -t nucl


        if [ $ref = "cool" ]
        then
            awk 'NR == 2 { print \$4 }' seq_typing.report_types.tab > reference
            parse_fasta.py -t \$(cat reference)  -f /NGStools/seq_typing/reference_sequences/dengue_virus/1_GenotypesDENV_14-05-18.fasta
        fi

        # Add information to dotfiles
        json_str="{'tableRow':[{'sample':'${sample_id}','data':[{'header':'seqtyping','value':'\$(cat seq_typing.report.txt)','table':'typing'}]}],'metadata':[{'sample':'${sample_id}','treeData':'\$(cat seq_typing.report.txt)','column':'typing'}]}"
        echo \$json_str > .report.json
        version_str="[{'program':'seq_typing.py','version':'0.1'}]"
        echo \$version_str > .versions

        rm -r rematch_temp

        if [ -s seq_typing.report.txt ];
        then
            echo pass > .status
        else
            echo fail > .status
        fi
    } || {
        echo fail > .status
        json_str="{'tableRow':[{'sample':'${sample_id}','data':[{'header':'seqtyping','value':'NA','table':'typing'}]}]}"
        echo \$json_str > .report.json
    }
    """

}

