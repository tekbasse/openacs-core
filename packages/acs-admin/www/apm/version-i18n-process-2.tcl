ad_page_contract {
    Internationalize a certain adp or tcl file.

    @author Peter Marklund (peter@collaboraid.biz)
    @creation-date 8 October 2002
    @cvs-id $Id$  
} {
    version_id:integer,notnull    
    {files:multiple,notnull}
    {file_action:multiple}
    {message_keys:multiple ""}
}

set next_file [lindex $files 0]

set page_title "Internationalizing ADP File $next_file"
set context_bar [ad_context_bar $page_title]

# Figure out which actions to take on the selected adp:s
set replace_text_p [ad_decode [lsearch -exact $file_action replace_text] "-1" "0" "1"]
set replace_tags_p [ad_decode [lsearch -exact $file_action replace_tags] "-1" "0" "1"]

# We need either or both of the actions to be selected
if { (! $replace_text_p) && (! $replace_tags_p) } {
    ad_return_complaint "Invalid HTML Parameters" "You must choose an action to take on selected adp files, either replace_text or replace_tags or both."
    ad_script_abort
}

# Do text replacement
if { $replace_text_p } {
    # Process the next adp file in the list
    set text_file $next_file
    set number_of_processed_files 1

    ns_log Notice "Replacing text in file $text_file with message tags"
    append processing_html_result "<h3>Text replacements for $text_file</h3>"
    set adp_text_result_list [lang::util::replace_adp_text_with_message_tags "[acs_root_dir]/$text_file" write $message_keys]
    set text_replacement_list [lindex $adp_text_result_list 0]
    set text_untouched_list [lindex $adp_text_result_list 1]

    append processing_html_result "<b>Replaced [llength $text_replacement_list] texts</b>: <br />"
    foreach text_replacement $text_replacement_list {
        append processing_html_result "replaced text \"[lindex $text_replacement 1]\" using key [lindex $text_replacement 0] <br />"
    }

    if { [llength $text_untouched_list] > 0 } {
        append processing_html_result "<br /> [llength $text_untouched_list] pieces of text were left untouched. Please take note of these texts and do any necessary translations by manually inserting <#message_key text#> tags in the adp file (the message keys should contain only letters and underscores, the text in the tag must have greater than and lesser than signs HTML quoted). At a later stage you can then run the action \"Replace tags with text and insert into catalog\" on the file. The texts to consider for translation are: <br />"
    } else {
        append processing_html_result "<br /> [llength $text_untouched_list] pieces of text were left untouched."
    }
    foreach untouched_text $text_untouched_list {
        append processing_html_result "\"$untouched_text\" <br />"
    }
}

# Do tag replacement
if { $replace_tags_p } {
    if { $replace_text_p } {
        # We are also replacing text, so only process one adp file
        set tags_files $next_file
        set number_of_processed_files 1
    } else {
        # We are only doing tag replacement, so process all adp files
        set tags_files $files
        set number_of_processed_files [llength $files]
    }

    foreach file $tags_files {
        ns_log Notice "Replacing tags in file $file with keys and doing insertion into message catalog"
        append processing_html_result "<h3>Message tag replacements for $file</h3>"

        set number_of_replacements [lang::util::replace_temporary_tags_with_lookups $file]

        append processing_html_result "Did $number_of_replacements replacements, any further details are in the log file"
    }
}    

# Remove the processed file from the file list.
set files [lrange $files $number_of_processed_files end]

# The proceed link will be to the next adp file if there is one and back to the I18N page
# if we're done
set proceed_url_export_vars [export_vars -url {version_id files:multiple file_action:multiple}]
if { [llength $files] > 0 } {
    # There are no more files to process so present a link back to the i18n page for this version
    set proceed_url "version-i18n-process?${proceed_url_export_vars}"
    set proceed_label "<b>Process next adp file</b>"

} else {
    # There are more files to process. This means we are doing text replacements
    # so present a link back to the page for choosing keys for the next adp file
    set proceed_url "version-i18n?${proceed_url_export_vars}"
    set proceed_label "Return to the I18N page for this package"
}

ad_return_template
