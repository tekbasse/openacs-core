<?xml version="1.0"?>
<queryset>
  
    <fullquery name="parameter_table">
        <querytext>
            select p.parameter_id,
                   p.parameter_name,
                   p.package_key,
                   coalesce(p.description, 'No Description') as description,
                   v.attr_value,
                   coalesce(p.section_name, 'No Section Name') as section_name
            from apm_parameters p left outer join
                 (select v.parameter_id,
                         v.attr_value
                  from apm_parameter_values v
                  where v.package_id = :package_id) v
            on p.parameter_id = v.parameter_id
            where p.package_key = (select package_key from apm_packages where package_id = :package_id)
            $additional_sql
        </querytext>
    </fullquery>

</queryset>
