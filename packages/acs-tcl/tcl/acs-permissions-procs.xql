<?xml version="1.0"?>
<queryset>

<fullquery name="ad_permission_p.n_privs">      
      <querytext>
      
      select count(*)
        from acs_privileges
       where privilege = :privilege
  
      </querytext>
</fullquery>

    <fullquery name="permission::set_inherit.set_inherit">
        <querytext>
            update acs_objects
            set security_inherit_p = 't'
            where object_id = :object_id
        </querytext>
    </fullquery>
 
    <fullquery name="permission::set_inherit.set_not_inherit">
        <querytext>
            update acs_objects
            set security_inherit_p = 'f'
            where object_id = :object_id
        </querytext>
    </fullquery>
 
</queryset>
