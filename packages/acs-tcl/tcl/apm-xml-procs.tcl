ad_library {

    Functions that APM uses to parse and generate XML.
    Changed to use ns_xml by ben (OpenACS).

    @author Bryan Quinn (bquinn@arsdigita.com)
    @author Ben Adida (ben@mit.edu)
    @creation-date Fri Oct  6 21:47:39 2000
    @cvs-id $Id$
} 

ad_proc -private -deprecated -warn apm_load_xml_packages {} {

    <p>
    NOTE: This proc doesn't do anything anymore.
    </p>

    <p>
    Loads XML packages into the running interpreter, if they're not
    already there. We need to load these packages once per connection,
    since AOLserver doesn't seem to deal with packages very well.
    </p>

} {
}

ad_proc -private apm_required_attribute_value { element attribute } {

    Returns an attribute of an XML element, throwing an error if the attribute
    is not set.

} {
    set value [apm_attribute_value $element $attribute]
    if { [empty_string_p $value] } {
	error "Required attribute \"$attribute\" missing from <[dom::node cget $element -nodeName]>"
    }
    return $value
}

ad_proc -private apm_attribute_value {
    {
	-default ""
    }
    element attribute } {

    Parses the XML element to return the value for the specified attribute.

} {
    # set value [dom::element getAttribute $element $attribute]
    set value [ns_xml node getattr $element $attribute]

    if { [empty_string_p $value] } {
	return $default
    } else {
	return $value
    }
}

ad_proc -private apm_tag_value {
    {
	-default ""
    }
    root property_name
} {
    Parses the XML element and returns the associated property name if it exists.
} {
    # set node [lindex [dom::element getElementsByTagName $root $property_name] 0]
    set node [lindex [xml_node_get_children_by_name $root $property_name] 0]

    if { ![empty_string_p $node] } {
	# return [dom::node cget [dom::node cget $node -firstChild] -nodeValue]
        set child [lindex [ns_xml node children $node] 0]

        # JCD 20020914 ns_xml when given something like <pretty-name></pretty-name> (i.e. empty content)
        # will have the node but the node will not have a child node and the 
        # getcontent will then fail.
        if { ![empty_string_p $child] } {
            return [ns_xml node getcontent $child]
        }
    }    
    return $default
}

ad_proc -private apm_generate_package_spec { version_id } {

    Generates an XML-formatted specification for a version of a package.

} {
    set spec {}

    db_1row package_version_select {}

    apm_log APMDebug "APM: Writing Package Specification for $pretty_name $version_name"
    set auto_mount_tag [ad_decode $auto_mount "" "" "<auto-mount>$auto_mount</auto-mount>\n"]
    append spec "<?xml version=\"1.0\"?>
<!-- Generated by the OpenACS Package Manager -->

<package key=\"[ad_quotehtml $package_key]\" url=\"[ad_quotehtml $package_uri]\" type=\"$package_type\">
    <package-name>[ad_quotehtml $pretty_name]</package-name>
    <pretty-plural>[ad_quotehtml $pretty_plural]</pretty-plural>
    <initial-install-p>$initial_install_p</initial-install-p>
    <singleton-p>$singleton_p</singleton-p>
    ${auto_mount_tag}
    <version name=\"$version_name\" url=\"[ad_quotehtml $version_uri]\">\n"

    db_foreach owner_info {} {
        append spec "        <owner"
        if { ![empty_string_p $owner_uri] } {
    	append spec " url=\"[ad_quotehtml $owner_uri]\""
        }
        append spec ">[ad_quotehtml $owner_name]</owner>\n"
    }

    apm_log APMDebug "APM: Writing Version summary and description"
    if { ![empty_string_p $summary] } {
        append spec "        <summary>[ad_quotehtml $summary]</summary>\n"
    }
    if { ![empty_string_p $release_date] } {
        append spec "        <release-date>[ad_quotehtml [string range $release_date 0 9]]</release-date>\n"
    }
    if { ![empty_string_p $vendor] || ![empty_string_p $vendor_uri] } {
        append spec "        <vendor"
        if { ![empty_string_p $vendor_uri] } {
    	append spec " url=\"[ad_quotehtml $vendor_uri]\""
        }
        append spec ">[ad_quotehtml $vendor]</vendor>\n"
    }
    if { ![empty_string_p $description] } {
        append spec "        <description"
        if { ![empty_string_p $description_format] } {
	    append spec " format=\"[ad_quotehtml $description_format]\""
        }
        append spec ">[ad_quotehtml $description]</description>\n"
    }

    append spec "\n"
    
    apm_log APMDebug "APM: Writing Dependencies."
    db_foreach dependency_info {} {
        append spec "        <$dependency_type url=\"[ad_quotehtml $service_uri]\" version=\"[ad_quotehtml $service_version]\"/>\n"
    } else {
        append spec "        <!-- No dependency information -->\n"
    }

    append spec "\n        <callbacks>\n"
    apm_log APMDebug "APM: Writing callbacks"
    db_foreach callback_info {} {
        append spec "            <callback type=\"[ad_quotehtml $type]\" \
                                           proc=\"[ad_quotehtml $proc]\"/>\n"
    }
    append spec "        </callbacks>"
    append spec "\n        <parameters>\n"
    apm_log APMDebug "APM: Writing parameters"
    db_foreach parameter_info {} {
	append spec "            <parameter datatype=\"[ad_quotehtml $datatype]\" \
		min_n_values=\"[ad_quotehtml $min_n_values]\" \
		max_n_values=\"[ad_quotehtml $max_n_values]\" \
		name=\"[ad_quotehtml $parameter_name]\" "
	if { ![empty_string_p $default_value] } {
	    append spec " default=\"[ad_quotehtml $default_value]\""
	}

	if { ![empty_string_p $description] } {
	    append spec " description=\"[ad_quotehtml $description]\""
	}
	
	if { ![empty_string_p $section_name] } {
	    append spec " section_name=\"[ad_quotehtml $section_name]\""
	}

	append spec "/>\n"
    } if_no_rows {
	append spec "        <!-- No version parameters -->\n"
    }

    append spec "        </parameters>\n\n"

    
    append spec "    </version>
</package>
"
    apm_log APMDebug "APM: Finished writing spec."
    return $spec
}


ad_proc -public apm_read_package_info_file { path } {

    Reads a .info file, returning an array containing the following items:

    <ul>
    <li><code>path</code>: a path to the file read
    <li><code>mtime</code>: the mtime of the file read
    <li><code>provides</code> and <code>$requires</code>: lists of dependency
    information, containing elements of the form <code>[list $url $version]</code>
    <li><code>owners</code>: a list of owners containing elements of the form
    <code>[list $url $name]</code>
    <li><code>files</code>: a list of files in the package,
    containing elements of the form <code>[list $path
    $type]</code> NOTE: Files are no longer stored in info files but are always retrieved
    directly from the file system. This element in the array will always be the empty list.
    <li><code>callbacks</code>: an array list of callbacks of the package
    on the form <code>[list callback_type1 proc_name1 callback_type2 proc_name2 ...] 
    <li>Element and attribute values directly from the XML specification:
    <code>package.key</code>,
    <code>package.url</code>,
    <code>package.type</code>
    <code>pretty-plural</code>
    <code>initial-install-p</code>
    <code>singleton-p</code>
    <code>auto-mount</code>
    <code>name</code> (the version name, e.g., <code>3.3a1</code>,
    <code>url</code> (the version URL),
    <code>package-name</code>,
    <code>option</code>,
    <code>summary</code>,
    <code>description</code>,
    <code>release-date</code>,
    <code>vendor</code>,
    <code>group</code>,
    <code>vendor.url</code>, and
    <code>description.format</code>.

    </ul>
    
    This routine will typically be called like so:
    
    <blockquote><pre>array set version_properties [apm_read_package_info_file $path]</pre></blockquote>

    to populate the <code>version_properties</code> array.

    <p>If the .info file cannot be read or parsed, this routine throws a
    descriptive error.

} {
    global ad_conn

    # If the .info file hasn't changed since last read (i.e., has the same
    # mtime), return the cached info list.
    set mtime [file mtime $path]
    if { [nsv_exists apm_version_properties $path] } {
	set cached_version [nsv_get apm_version_properties $path]
	if { [lindex $cached_version 0] == $mtime } {
	    return [lindex $cached_version 1]
	}
    }

    # Set the path and mtime in the array.
    set properties(path) $path
    set properties(mtime) $mtime

    apm_load_xml_packages

    apm_log APMDebug "Reading specification file at $path"

    set file [open $path]
    set xml_data [read $file]
    close $file

    set xml_data [xml_prepare_data $xml_data]

    # set tree [dom::DOMImplementation parse $xml_data]
    set tree [xml_parse $xml_data]
    # set package [dom::node cget $tree -firstChild]
    set root_node [xml_doc_get_first_node_by_name $tree package]
    apm_log APMDebug "XML: root node is [ns_xml node name $root_node]"
    set package $root_node

    # set root_name [dom::node cget $package -nodeName]
    set root_name [xml_node_get_name $package]

    # Debugging Children
    set root_children [xml_node_get_children $root_node]

    apm_log APMDebug "XML - there are [llength $root_children] child nodes"
    foreach child $root_children {
	apm_log APMDebug "XML - one root child: [xml_node_get_name $child]"
    }

    if { ![string equal $root_name "package"] } {
	apm_log APMDebug "XML: the root name is $root_name"
	error "Expected <package> as root node"
    }
    set properties(package.key) [apm_required_attribute_value $package key]
    set properties(package.url) [apm_required_attribute_value $package url]
    set properties(package.type) [apm_attribute_value -default "apm_application" $package type]
    set properties(package-name) [apm_tag_value $package package-name]
    set properties(initial-install-p) [apm_tag_value -default "f" $package initial-install-p]
    set properties(singleton-p) [apm_tag_value -default "f" $package singleton-p]
    set properties(auto-mount) [apm_tag_value -default "" $package auto-mount]
    set properties(pretty-plural) [apm_tag_value -default "$properties(package-name)s" $package pretty-plural]


    # set versions [dom::element getElementsByTagName $package version]
    set versions [xml_node_get_children_by_name $package version]

    if { [llength $versions] != 1 } {
	error "Package must contain exactly one <version> node"
    }
    set version [lindex $versions 0]
    
    set properties(name) [apm_required_attribute_value $version name]
    set properties(url) [apm_required_attribute_value $version url]


    # Set an entry in the properties array for each of these tags.
    foreach property_name { summary description release-date vendor } {
	set properties($property_name) [apm_tag_value $version $property_name]
    }


    # Set an entry in the properties array for each of these attributes:
    #
    #   <vendor url="...">           -> vendor.url
    #   <description format="...">   -> description.format

    foreach { property_name attribute_name } {
	vendor url
	description format
    } {
	# set node [lindex [dom::element getElementsByTagName $version $property_name] 0]
	set node [lindex [xml_node_get_children_by_name $version $property_name] 0]
	if { ![empty_string_p $node] } {
	    # set properties($property_name.$attribute_name) [dom::element getAttribute $node $attribute_name]
	    set properties($property_name.$attribute_name) [apm_attribute_value $node $attribute_name]
	} else {
	    set properties($property_name.$attribute_name) ""
	}
    }

    # We're done constructing the properties array - save the properties into the
    # moby array which we're going to return.

    set properties(properties) [array get properties]

    # Build lists of the services provided by and required by the package.

    set properties(provides) [list]
    set properties(requires) [list]

    foreach dependency_type { provides requires } {
	# set dependency_types [dom::element getElementsByTagName $version $dependency_type]
	set dependency_types [xml_node_get_children_by_name $version $dependency_type]

	foreach node $dependency_types {
	    set service_uri [apm_required_attribute_value $node url]
	    set service_version [apm_required_attribute_value $node version]
	    lappend properties($dependency_type) [list $service_uri $service_version]
	}
    }

    set properties(files) [list]

    # Build a list of package callbacks
    array set callback_array {}

    set callbacks_node_list [xml_node_get_children_by_name $version callbacks]

    foreach callbacks_node $callbacks_node_list {
        
        set callback_node_list [xml_node_get_children_by_name $callbacks_node callback]
        foreach callback_node $callback_node_list {

            set type [apm_attribute_value $callback_node type]
            set proc [apm_attribute_value $callback_node proc]

            if { [llength [array get callback_array $type]] != 0 } {
                # A callback proc of this type already found in the xml file
                ns_log Error "package info file $path contains more than one callback proc of type $type"
                continue
            }
            
            if { [lsearch -exact [apm_supported_callback_types] $type] < 0 } {
                # The callback type is not supported
                ns_log Error "package info file $path contains an unsupported callback type $type - ignoring. Valid values are [apm_supported_callback_types]"
                continue
            }

            set callback_array($type) $proc
        }
    }

    set properties(callbacks) [array get callback_array]


    # Build a list of the package's owners (if any).

    set properties(owners) [list]

    # set owners [dom::element getElementsByTagName $version "owner"]
    set owners [xml_node_get_children_by_name $version owner]

    foreach node $owners {
	# set url [dom::element getAttribute $node url]
	set url [apm_attribute_value $node url]
	# set name [dom::node cget [dom::node cget $node -firstChild] -nodeValue]
	set name [xml_node_get_content [lindex [xml_node_get_children $node] 0]]
	lappend properties(owners) [list $name $url]
    }

    # Build a list of the packages parameters (if any)

    set properties(parameters) [list]
    apm_log APMDebug "APM: Reading Parameters"

    # set parameters [dom::element getElementsByTagName $version "parameters"]
    set parameters [xml_node_get_children_by_name $version parameters]

    foreach node $parameters {
	# set parameter_nodes [dom::element getElementsByTagName $node "parameter"]
	set parameter_nodes [xml_node_get_children_by_name $node parameter]

	foreach parameter_node $parameter_nodes {	  
	    # set default_value [dom::element getAttribute $parameter_node default]
	    set default_value [apm_attribute_value $parameter_node default]
	    # set min_n_values [dom::element getAttribute $parameter_node min_n_values]
	    set min_n_values [apm_attribute_value $parameter_node min_n_values]
	    # set max_n_values [dom::element getAttribute $parameter_node max_n_values]
	    set max_n_values [apm_attribute_value $parameter_node max_n_values]
	    # set description [dom::element getAttribute $parameter_node description]
	    set description [apm_attribute_value $parameter_node description]
	    # set section_name [dom::element getAttribute $parameter_node section_name]
	    set section_name [apm_attribute_value $parameter_node section_name]
	    # set datatype [dom::element getAttribute $parameter_node datatype]
	    set datatype [apm_attribute_value $parameter_node datatype]
	    # set name [dom::element getAttribute $parameter_node name]
	    set name [apm_attribute_value $parameter_node name]

	    apm_log APMDebug "APM: Reading parameter $name with default $default_value"
	    lappend properties(parameters) [list $name $description $section_name $datatype $min_n_values $max_n_values $default_value]
	}
    }

    # Serialize the array into a list.
    set return_value [array get properties]

    # Cache the property info based on $mtime.
    nsv_set apm_version_properties $path [list $mtime $return_value]

    return $return_value
}
