*** Settings ***
Resource    api.resource
Library     SSHLibrary

*** Variables ***
# Set it to reuse the mail module already installed on a dev node
${MAIL_MODULE}         ${EMPTY}
${user_domain_ldap}    ldap.dom.test
${list_domain}         lists.test

*** Test Cases ***
Install the user domain and the mail module
    IF    '${MAIL_MODULE}' != ''
        Set Global Variable    ${mail_id}    ${MAIL_MODULE}
        Set Global Variable    ${mail_installed}    ${FALSE}
        Pass Execution    reusing ${MAIL_MODULE}
    END
    ${response} =    Run task    cluster/add-internal-provider    {"image":"openldap","node":1}
    Run task    module/${response['module_id']}/configure-module    {"domain":"${user_domain_ldap}","admuser":"admin","admpass":"Nethesis,1234","provision":"new-domain"}
    ${output}  ${rc} =    Execute Command    add-module mail 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${mail_id}    ${output.module_id}
    Set Global Variable    ${mail_installed}    ${TRUE}
    Run task    module/${mail_id}/configure-module
    ...    {"hostname":"mail.domain.test","user_domain":"${user_domain_ldap}","mail_domain":"domain.test"}

Add the list domain to the mail module
    Run task    module/${mail_id}/add-domain
    ...    {"domain":"${list_domain}","addusers":false,"addgroups":false,"addaliases":false,"catchall":null,"bccaddr":null,"description":"Sympa tests"}
    Set Global Variable    ${list_domain}

Add a test user with a mailbox
    ${config} =    Run task    module/${mail_id}/get-configuration    {}
    ${domains} =    Run task    module/${mail_id}/list-domains    {}
    ${mail_domain} =    Evaluate    [d['domain'] for d in $domains if d['addusers']][0]
    Set Global Variable    ${ldap_id}    ${config['user_domain']['providers'][0]['id']}
    Set Global Variable    ${test_user}    sympatester
    Set Global Variable    ${test_password}    Nethesis,1234
    Set Global Variable    ${test_mail}    sympatester@${mail_domain}
    Run task    module/${ldap_id}/add-user
    ...    {"user":"${test_user}","display_name":"Sympa Tester","password":"${test_password}","mail":"${test_mail}"}
