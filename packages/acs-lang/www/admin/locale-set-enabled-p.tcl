ad_page_contract {

    Sets enabled_p for a locale.

    @author Simon Carstensen (simon@collaboraid.biz)

    @creation-date 2003-08-08
} {
    locale
    enabled_p:boolean
}

lang::system::locale_set_enabled \
        -locale $locale \
        -enabled_p $enabled_p

ad_returnredirect . 
ad_script_abort
