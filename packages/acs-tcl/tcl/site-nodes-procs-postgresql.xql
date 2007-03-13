<?xml version="1.0"?>

<queryset>
    <rdbms><type>postgresql</type><version>7.1</version></rdbms>

    <fullquery name="site_node::delete.delete_site_node">
        <querytext>
            select site_node__delete(:node_id);
        </querytext>
    </fullquery>

    <fullquery name="site_node::update_cache.select_child_site_nodes">
        <querytext>
	    select n.node_id,
		   n.parent_id,
		   n.name,
		   n.directory_p,
		   n.pattern_p,
		   n.object_id,
		   p.package_key,
		   p.package_id,
		   p.instance_name,
		   t.package_type,
		   (select count(*) from site_nodes where parent_id = n.node_id) as num_children
            from site_nodes n left join
                 apm_packages p on n.object_id = p.package_id left join
                 apm_package_types t using (package_key)
	    where n.tree_sortkey between site_node_get_tree_sortkey(:node_id)
	                         and tree_right(site_node_get_tree_sortkey(:node_id))
	    order by n.tree_sortkey
        </querytext>
    </fullquery>

    <fullquery name="site_node::update_cache.select_direct_child_site_nodes">
        <querytext>
	    select n.node_id,
		   n.parent_id,
		   n.name,
		   n.directory_p,
		   n.pattern_p,
		   n.object_id,
		   p.package_key,
		   p.package_id,
		   p.instance_name,
		   t.package_type,
		   (select count(*) from site_nodes where parent_id = n.node_id) as num_children
            from site_nodes n left join
                 apm_packages p on n.object_id = p.package_id left join
                 apm_package_types t using (package_key)
	    where n.node_id = :node_id or n.parent_id = :node_id
	    order by n.tree_sortkey
        </querytext>
    </fullquery>

    <fullquery name="site_node::update_cache.select_site_node">
        <querytext>
	    select n.node_id,
		   n.parent_id,
		   n.name,
		   n.directory_p,
		   n.pattern_p,
		   n.object_id,
		   p.package_key,
		   p.package_id,
		   p.instance_name,
		   t.package_type,
		   (select count(*) from site_nodes where parent_id = n.node_id) as num_children
            from site_nodes n left join 
                 apm_packages p on n.object_id = p.package_id left join
                 apm_package_types t using (package_key)
            where n.node_id = :node_id
        </querytext>
    </fullquery>

    <fullquery name="site_node::get_url_from_object_id.select_url_from_object_id">
        <querytext>
            select site_node__url(node_id)
            from site_nodes
            where object_id = :object_id
            order by site_node__url(node_id) desc
        </querytext>
    </fullquery>

</queryset>
