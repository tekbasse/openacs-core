ad_library {
    Procs for local authentication.

    @author Lars Pind (lars@collaobraid.biz)
    @creation-date 2003-05-13
    @cvs-id $Id$
}

namespace eval auth {}
namespace eval auth::local {}
namespace eval auth::local::authentication {}
namespace eval auth::local::password {}
namespace eval auth::local::registration {}



#####
#
# auth::local
#
#####

ad_proc -private auth::local::install {} {
    Register local service contract implementations, 
    and update the local authority with live information.
} {
    db_transaction {
        # Register the local service contract implementations
        set row(auth_impl_id) [auth::local::authentication::register_impl]
        set row(pwd_impl_id) [auth::local::password::register_impl]
        set row(register_impl_id) [auth::local::registration::register_impl]
        
        # Set the authority pretty-name to be the system name
        set row(pretty_name) [ad_system_name]
        
        auth::authority::edit \
            -authority_id [auth::authority::local] \
            -array row
    }
}

ad_proc -private auth::local::uninstall {} {
    Unregister the local service contract implementation, and update the 
    local authority to reflect that.
} {
    db_transaction {
        # Update the local authority to reflect the loss of the implementations
        set row(auth_impl_id) {}
        set row(pwd_impl_id) {}
        set row(register_impl_id) {}

        auth::authority::edit \
            -authority_id [auth::authority::local] \
            -array row

        # Unregister the implementations
        auth::local::authentication::unregister_impl
        auth::local::password::unregister_impl
        auth::local::registration::unregister_impl
    }
}




#####
#
# auth::local::authentication
#
#####
#
# The 'auth_authentication' service contract implementation
#

ad_proc -private auth::local::authentication::register_impl {} {
    Register the 'local' implementation of the 'auth_authentication' service contract.
    
    @return impl_id of the newly created implementation.
} {
    set spec {
        contract_name "auth_authentication"
        owner "acs-authentication"
        name "local"
        pretty_name "Local"
        aliases {
            Authenticate auth::local::authentication::Authenticate
            GetParameters auth::local::authentication::GetParameters
        }
    }

    return [acs_sc::impl::new_from_spec -spec $spec]
}

ad_proc -private auth::local::authentication::unregister_impl {} {
    Unregister the 'local' implementation of the 'auth_authentication' service contract.
} {
    acs_sc::impl::delete -contract_name "auth_authentication" -impl_name "local"
}


ad_proc -private auth::local::authentication::Authenticate {
    username
    password
    {parameters {}}
} {
    Implements the Authenticate operation of the auth_authentication 
    service contract for the local account implementation.
} {
    array set auth_info [list]

    # usernames are case insensitive
    set username [string tolower $username]
    
    set authority_id [auth::authority::local]

    set user_id [acs_user::get_by_username -username $username]
    if { [empty_string_p $user_id] } {
        set result(auth_status) "no_account"
        return [array get result]
    }

    if { [ad_check_password $user_id $password] } {
        set auth_info(auth_status) "ok"
    } else {
        set auth_info(auth_status) "bad_password"
        set auth_info(auth_message) "Invalid username or password"
        return [array get auth_info]
    }

    # We set 'external' account status to 'ok', because the 
    # local account status will be checked anyways by the framework
    set auth_info(account_status) ok

    return [array get auth_info]
}

ad_proc -private auth::local::authentication::GetParameters {} {
    Implements the GetParameters operation of the auth_authentication 
    service contract for the local account implementation.
} {
    # No parameters
    return [list]
}


#####
#
# auth::local::password
#
#####
#
# The 'auth_password' service contract implementation
#

ad_proc -private auth::local::password::register_impl {} {
    Register the 'local' implementation of the 'auth_password' service contract.
    
    @return impl_id of the newly created implementation.
} {
    set spec {
        contract_name "auth_password"
        owner "acs-authentication"
        name "local"
        pretty_name "Local"
        aliases {
            CanChangePassword auth::local::password::CanChangePassword
            ChangePassword auth::local::password::ChangePassword
            CanRetrievePassword auth::local::password::CanRetrievePassword
            RetrievePassword auth::local::password::RetrievePassword
            CanResetPassword auth::local::password::CanResetPassword
            ResetPassword auth::local::password::ResetPassword
            GetParameters auth::local::password::GetParameters
        }
    }
    return [acs_sc::impl::new_from_spec -spec $spec]
}

ad_proc -private auth::local::password::unregister_impl {} {
    Unregister the 'local' implementation of the 'auth_password' service contract.
} {
    acs_sc::impl::delete -contract_name "auth_password" -impl_name "local"
}


ad_proc -private auth::local::password::CanChangePassword {
    {parameters ""}
} {
    Implements the CanChangePassword operation of the auth_password 
    service contract for the local account implementation.
} {
    # Yeah, we can change your password
    return 1
}

ad_proc -private auth::local::password::CanRetrievePassword {
    {parameters ""}
} {
    Implements the CanRetrievePassword operation of the auth_password 
    service contract for the local account implementation.
} {
    # Nope, passwords are stored hashed, so we can't retrieve it for you
    return 0
}

ad_proc -private auth::local::password::CanResetPassword {
    {parameters ""}
} {
    Implements the CanResetPassword operation of the auth_password 
    service contract for the local account implementation.
} {
    # Yeah, we can reset for you.
    return 1
}

ad_proc -private auth::local::password::ChangePassword {
    username
    old_password
    new_password
    {parameters {}}
} {
    Implements the ChangePassword operation of the auth_password 
    service contract for the local account implementation.
} {
    array set result { 
        password_status {}
        password_message {} 
    }

    set user_id [acs_user::get_by_username -username $username]
    if { [empty_string_p $user_id] } {
        set result(password_status) "no_account"
        return [array get result]
    }
    
    if { ![ad_check_password $user_id $old_password] } {
        set result(password_status) "old_password_bad"
        return [array get result]
    }
    if { [catch { ad_change_password $user_id $new_password } errmsg] } {
        set result(password_status) "change_error"
        global errorInfo
        ns_log Error "Error changing local password for username $username, user_id $user_id: \n$errorInfo"
        return [array get result]
    }

    set result(password_status) "ok"

    if { [parameter::get -parameter EmailAccountOwnerOnPasswordChangeP -package_id [ad_acs_kernel_id] -default 1] } {
        acs_user::get -username $username -array user

        set system_name [ad_system_name]
        set pvt_home_name [ad_pvt_home_name]
        set password_update_link_text [_ acs-subsite.Change_my_Password]
        
        if { [auth::UseEmailForLoginP] } {
            set account_id_label [_ acs-subsite.Email]
            set account_id $user(email)
        } else {
            set account_id_label [_ acs-subsite.Username]
            set account_id $user(username)
        }

        set subject [_ acs-subsite.Password_changed_subject]
        set body [_ acs-subsite.Password_changed_body]

        ns_sendmail \
            $user(email) \
            [ad_outgoing_sender] \
            $subject \
            $body
    }
    
    return [array get result]
}

ad_proc -private auth::local::password::RetrievePassword {
    username
    parameters
} {
    Implements the RetrievePassword operation of the auth_password 
    service contract for the local account implementation.
} {
    set result(password_status) "not_supported"
    set result(password_message) [_ acs-subsite.cannot_retrieve_password]

    return [array get result]
}

ad_proc -private auth::local::password::ResetPassword {
    username
    parameters
} {
    Implements the ResetPassword operation of the auth_password 
    service contract for the local account implementation.
} {
    array set result { 
        password_status ok
        password_message {} 
    }

    set user_id [acs_user::get_by_username -username $username]
    if { [empty_string_p $user_id] } {
        set result(password_status) "no_account"
        return [array get result]
    }

    # Reset the password
    set password [ad_generate_random_string]

    ad_change_password $user_id $password

    # We return the new passowrd here and let the OpenACS framework send the email with the new password
    set result(password) $password

    return [array get result]
}

ad_proc -private auth::local::password::GetParameters {} {
    Implements the GetParameters operation of the auth_password
    service contract for the local account implementation.
} {
    # No parameters
    return [list]
}


#####
#
# auth::local::register
#



#####
#
# The 'auth_registration' service contract implementation
#

ad_proc -private auth::local::registration::register_impl {} {
    Register the 'local' implementation of the 'auth_registration' service contract.
    
    @return impl_id of the newly created implementation.
} {
    set spec {
        contract_name "auth_registration"
        owner "acs-authentication"
        name "local"
        pretty_name "Local"
        aliases {
            GetElements auth::local::registration::GetElements
            Register auth::local::registration::Register
            GetParameters auth::local::registration::GetParameters
        }
    }
    return [acs_sc::impl::new_from_spec -spec $spec]
}

ad_proc -private auth::local::registration::unregister_impl {} {
    Unregister the 'local' implementation of the 'auth_register' service contract.
} {
    acs_sc::impl::delete -contract_name "auth_registration" -impl_name "local"
}

ad_proc -private auth::local::registration::GetElements {
    {parameters ""}
} {
    Implements the GetElements operation of the auth_register
    service contract for the local account implementation.
} {
    set result(required) {}
    if { ![auth::UseEmailForLoginP] } {
        set result(required) username 
    }

    set result(required) [concat $result(required) { email first_names last_name }]
    set result(optional) { url }

    if { ![parameter::get -parameter RegistrationProvidesRandomPasswordP -default 0] } {
        lappend result(optional) password
    }

    if { [parameter::get -parameter RequireQuestionForPasswordResetP -default 1] && 
         [parameter::get -parameter UseCustomQuestionForPasswordReset -default 1] } {
        lappend result(required) secret_question secret_answer 
    }

    return [array get result]
}

ad_proc -private auth::local::registration::Register {
    parameters
    username
    authority_id
    first_names
    last_name
    screen_name
    email
    url
    password
    secret_question
    secret_answer
} {
    Implements the Register operation of the auth_register
    service contract for the local account implementation.
} {
    array set result {
        creation_status "ok"
        creation_message {}
        element_messages {}
        account_status "ok"
        account_message {}
    }

    # We don't create anything here, so creation always succeeds
    # And we don't check local account, either

    # Generate random password?
    set generated_pwd_p 0
    if { [empty_string_p $password] || [parameter::get -parameter RegistrationProvidesRandomPasswordP -default 0] } {
        set password [ad_generate_random_string]
        set generated_pwd_p 1
    }

    # Set user's password
    set user_id [acs_user::get_by_username -username $username]
    ad_change_password $user_id $password

    # Used in messages below
    set system_name [ad_system_name]
    set system_url [ad_url]

    # Send password confirmation email to user
    if { $generated_pwd_p || \
             [parameter::get -parameter RegistrationProvidesRandomPasswordP -default 0] || \
             [parameter::get -parameter EmailRegistrationConfirmationToUserP -default 0] } {
	with_catch errmsg {
	    ns_sendmail \
                $email \
                [parameter::get -parameter NewRegistrationEmailAddress -default [ad_system_owner]] \
                [_ acs-subsite.lt_Welcome_to_system_nam] \
                [_ acs-subsite.lt_Thank_you_for_visitin]
	} {
            # We don't fail hard here, just log an error
            global errorInfo
	    ns_log Error "Error sending registration confirmation to $email.\n$errorInfo"
	}
    }

    # Notify admin on new registration
    if { [ad_parameter NotifyAdminOfNewRegistrationsP "security" 0] } {
	with_catch errmsg {
            ns_sendmail \
                [parameter::get -parameter NewRegistrationEmailAddress -default [ad_system_owner]] \
                $email \
                [_ acs-subsite.lt_New_registration_at_s] \
                [_ acs-subsite.lt_first_names_last_name]
	} {
            # We don't fail hard here, just log an error
            global errorInfo
	    ns_log Error "Error sending admin notification to $notification_address.\n$errorInfo"
	}
    }

    return [array get result]
}

ad_proc -private auth::local::registration::GetParameters {} {
    Implements the GetParameters operation of the auth_registration
    service contract for the local account implementation.
} {
    # No parameters
    return [list]
}
