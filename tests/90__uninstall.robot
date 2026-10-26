*** Settings ***
Resource    api.resource
Library     SSHLibrary

*** Test Cases ***
Remove the mail addresses of sympa
    FOR    ${local}    IN    @{sympa_locals}
        Run task    module/${mail_id}/remove-address    {"atype":"domain","domain":"${list_domain}","local":"${local}"}
    END
    Execute Command    rm -f /tmp/sympa-send-command.sh

Check if sympa is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if the relay rule is removed
    ${out} =    Execute Command    api-cli run module/${mail_id}/list-relay-rules
    Should Not Contain    ${out}    ${module_id}.invalid

Remove the list domain
    Run task    module/${mail_id}/remove-domain    {"domain":"${list_domain}"}

Remove the mail module and the user domain
    Skip If    not ${mail_installed}    ${mail_id} was already on the node
    ${rc} =    Execute Command    remove-module --no-preserve ${mail_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    Run task    cluster/remove-internal-domain    {"domain":"ldap.dom.test"}
