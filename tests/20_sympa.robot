*** Settings ***
Resource    api.resource
Library     SSHLibrary

*** Variables ***
${SCENARIO}    install
# sympa is not in the default NS8 repository, so the update starts from the last published release
${STABLE_IMAGE_URL}    ghcr.io/stephdl/sympa:1.0.0
${sympa_host}    sympa.domain.test
${list_name}     robotlist

*** Keywords ***
Services are active
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active sympa.service postgresql-app.service sympa-app.service postfix-app.service wwsympa-app.service
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Web interface answers
    ${out}  ${rc} =    Execute Command
    ...    curl -skf -H "Host: ${sympa_host}" https://127.0.0.1/sympa
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${out}    Sympa

SMTP service answers
    # Postfix listens on the node VPN address only, read it from the socket
    ${out}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'addr=$(ss -Hltn "sport = :$SMTP_PORT" | head -1 | tr -s " " | cut -d" " -f4); exec 3<>/dev/tcp/\${addr%:*}/$SMTP_PORT && timeout 5 head -c3 <&3'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Be Equal    ${out}    220

List has subscribers
    [Arguments]    ${count}
    ${response} =    Run task    module/${module_id}/list-lists    {}
    ${list} =    Evaluate    [l for l in $response['lists'] if l['name'] == '${list_name}'][0]
    Should Be Equal As Integers    ${list}[subscribers]    ${count}

Subscribe by mail
    [Arguments]    ${address}
    ${out}  ${err}  ${rc} =    Execute Command
    ...    /tmp/sympa-send-command.sh ${robot_address} ${address} "SUBSCRIBE ${list_name} Robot Tester"
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0    ${err}

Configuration is kept
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${config}[host]    ${sympa_host}
    Should Be Equal    ${config}[list_domain]    ${list_domain}
    Should Be Equal    ${config}[mail_server]    ${mail_uuid}
    Should Be True    ${config}[has_route]

*** Test Cases ***
Check if sympa is installed correctly
    ${image} =    Set Variable If    '${SCENARIO}' == 'update'    ${STABLE_IMAGE_URL}    ${IMAGE_URL}
    ${output}  ${rc} =    Execute Command    add-module ${image} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Check if sympa configuration reads back
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${config}[host]    ${EMPTY}
    ${mail} =    Evaluate    [m for m in $config['mail_servers'] if m['module_id'] == '${mail_id}'][0]
    Set Global Variable    ${mail_uuid}    ${mail}[uuid]
    Set Global Variable    ${user_domain}    ${mail}[internal_domain]

Check if sympa can be configured
    Run task    module/${module_id}/configure-module
    ...    {"host":"${sympa_host}","lets_encrypt":false,"list_domain":"${list_domain}","listmasters":["admin@${list_domain}"],"mail_server":"${mail_uuid}","user_domain":"${user_domain}","default_lang":"en-US"}
    Configuration is kept

Check if sympa services are running
    Wait Until Keyword Succeeds    30 times    5 seconds    Services are active
    Wait Until Keyword Succeeds    30 times    5 seconds    SMTP service answers

Check if the web interface answers
    Wait Until Keyword Succeeds    30 times    5 seconds    Web interface answers

Check if a list can be created
    Run task    module/${module_id}/create-list
    ...    {"name":"${list_name}","subject":"Robot list","type":"discussion_list","owners":["admin@${list_domain}"],"description":"Robot Framework test list"}
    List has subscribers    0

Declare the mail addresses of sympa and of the list
    # The UI declares them in production: create-list does not
    ${response} =    Run task    module/${module_id}/list-lists    {}
    ${config} =    Run task    module/${module_id}/get-configuration    {}
    ${inbound} =    Set Variable    ${config}[inbound_domain]
    ${locals} =    Evaluate    $response['robot_addresses'] + ['${list_name}' + s for s in $response['list_suffixes']]
    FOR    ${local}    IN    @{locals}
        Run task    module/${mail_id}/add-address
        ...    {"atype":"domain","domain":"${list_domain}","local":"${local}","destinations":[{"dtype":"external","name":"${local}@${inbound}"}]}
    END
    Set Global Variable    @{sympa_locals}    @{locals}
    Set Global Variable    ${robot_address}    ${response['robot_addresses'][0]}@${list_domain}
    Put File    ${CURDIR}/send-command.sh    /tmp/sympa-send-command.sh    mode=0755

Check if a subscription by mail reaches sympa
    Subscribe by mail    first@example.com
    Wait Until Keyword Succeeds    30 times    5 seconds    List has subscribers    1

Update sympa to the image under test
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    ${rc} =    Execute Command
    ...    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${image} =    Execute Command    runagent -m ${module_id} printenv IMAGE_URL
    Should Be Equal    ${image}    ${IMAGE_URL}

Check if the configuration survives the update
    Configuration is kept

Check if the services run after the update
    Wait Until Keyword Succeeds    30 times    5 seconds    Services are active
    Wait Until Keyword Succeeds    30 times    5 seconds    Web interface answers
    Wait Until Keyword Succeeds    30 times    5 seconds    SMTP service answers

Check if the list and its subscriber survive the update
    Wait Until Keyword Succeeds    30 times    5 seconds    List has subscribers    1

Check if mail still reaches sympa after the update
    Subscribe by mail    second@example.com
    Wait Until Keyword Succeeds    30 times    5 seconds    List has subscribers    2

Check if the list can be destroyed
    Run task    module/${module_id}/destroy-list    {"name":"${list_name}"}
    ${response} =    Run task    module/${module_id}/list-lists    {}
    ${names} =    Evaluate    [l['name'] for l in $response['lists']]
    Should Not Contain    ${names}    ${list_name}
