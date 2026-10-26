*** Settings ***
Resource    api.resource
Library     SSHLibrary
Library     Collections
Suite Teardown    Restore the cluster smarthost

*** Variables ***
${SCENARIO}    install
# sympa is not in the default NS8 repository, so the update starts from the last published release
${STABLE_IMAGE_URL}    ghcr.io/stephdl/sympa:1.0.0
${sympa_host}    sympa.domain.test
${list_name}     robotlist
${saved_smarthost}    ${NONE}

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
    ...    /tmp/sympa-send-mail.sh ${robot_address} ${address} "SUBSCRIBE ${list_name} Robot Tester"
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0    ${err}

Pod start time
    ${out} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user show sympa.service -p ActiveEnterTimestampMonotonic --value
    RETURN    ${out}

Pod restarted since
    [Arguments]    ${before}
    ${now} =    Pod start time
    Should Not Be Equal    ${now}    ${before}
    Services are active

Validation fails with
    [Arguments]    ${action}    ${input}    ${error}    ${rc}=2
    ${response} =    Run task    module/${module_id}/${action}    ${input}    rc_expected=${rc}
    ${errors} =    Evaluate    [e['error'] for e in $response]
    Should Contain    ${errors}    ${error}

Configure sympa
    [Arguments]    ${host}=${sympa_host}    ${list_domain}=${list_domain}    ${listmasters}=["admin@${list_domain}"]
    ...    ${mail_server}=${mail_uuid}    ${user_domain}=${user_domain}    ${lang}=en-US    ${rc}=2    ${error}=${EMPTY}
    ${input} =    Set Variable
    ...    {"host":"${host}","lets_encrypt":false,"list_domain":"${list_domain}","listmasters":${listmasters},"mail_server":"${mail_server}","user_domain":"${user_domain}","default_lang":"${lang}"}
    IF    '${error}' != ''
        Validation fails with    configure-module    ${input}    ${error}    rc=${rc}
    ELSE
        Run task    module/${module_id}/configure-module    ${input}
    END

Set the cluster smarthost
    [Arguments]    ${settings}
    ${data} =    Evaluate    shlex.quote(json.dumps($settings))    modules=json,shlex
    ${out}  ${err}  ${rc} =    Execute Command    api-cli run cluster/set-smarthost --data ${data}
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0    ${err}

Restore the cluster smarthost
    IF    $saved_smarthost is not None
        Set the cluster smarthost    ${saved_smarthost}
    END

Relay host is
    [Arguments]    ${expected}
    ${out} =    Execute Command    runagent -m ${module_id} podman exec postfix-app postconf -h relayhost
    Should Be Equal    ${out}    ${expected}

Mailbox has a message
    [Arguments]    ${subject}
    ${out} =    Execute Command
    ...    runagent -m ${mail_id} podman exec dovecot doveadm search -u ${test_user} mailbox INBOX subject "${subject}"
    Should Not Be Empty    ${out}

Login on the web interface
    [Arguments]    ${password}
    # Sympa does not keep the session of clients it takes for crawlers, like curl
    ${out}  ${rc} =    Execute Command
    ...    J=$(mktemp); trap 'rm -f $J' EXIT; C="curl -sk -A Mozilla/5.0 --resolve ${sympa_host}:443:127.0.0.1 -c $J -b $J"; U=https://${sympa_host}/sympa; tok=$($C $U/login | grep -oP 'name="csrftoken" value="\K[^"]+' | head -1); $C -o /dev/null --data-urlencode csrftoken=$tok --data-urlencode action=login --data-urlencode submit=submit --data-urlencode email=${test_user} --data-urlencode 'passwd=${password}' $U && $C $U
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    RETURN    ${out}

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

Check if lists cannot be created before the configuration
    Skip If    '${SCENARIO}' == 'update'    the release under update fails here with a traceback
    Validation fails with    create-list
    ...    {"name":"${list_name}","subject":"Robot list","type":"discussion_list","owners":["admin@${list_domain}"]}
    ...    module_not_configured

Check if sympa can be configured
    Configure sympa
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
    Put File    ${CURDIR}/send-mail.sh    /tmp/sympa-send-mail.sh    mode=0755

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

Check if an undeclared address is rejected
    ${out}  ${err}  ${rc} =    Execute Command
    ...    curl -sv --mail-from tester@example.com --mail-rcpt nobody-${module_id}@${list_domain} -T /dev/null smtp://127.0.0.1:25/example.com
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  55
    Should Contain    ${err}    < 550

Check if invalid configurations are refused
    Configure sympa    mail_server=00000000-0000-0000-0000-000000000000    error=mail_server_not_found
    Configure sympa    list_domain=nowhere.test    error=list_domain_not_in_mail_server
    Configure sympa    user_domain=nowhere.test    error=user_domain_not_found
    Configure sympa    listmasters=[]    rc=10    error=listmasters_array_min_items
    Configuration is kept

Check if invalid lists are refused
    ${reserved} =    Evaluate    '${robot_address}'.split('@')[0]
    Validation fails with    create-list
    ...    {"name":"${list_name}","subject":"Again","type":"discussion_list","owners":["admin@${list_domain}"]}
    ...    list_already_exists
    Validation fails with    create-list
    ...    {"name":"${reserved}","subject":"Reserved","type":"discussion_list","owners":["admin@${list_domain}"]}
    ...    list_name_reserved
    Validation fails with    create-list
    ...    {"name":"Bad Name","subject":"Bad","type":"discussion_list","owners":["admin@${list_domain}"]}
    ...    name_pattern    rc=10
    Validation fails with    destroy-list    {"name":"missing-list"}    list_not_found

Check if an LDAP user can log in to the web interface
    ${page} =    Login on the web interface    ${test_password}
    Should Contain    ${page}    ${test_mail}
    ${page} =    Login on the web interface    wrong-password
    Should Not Contain    ${page}    ${test_mail}

Check if sympa restarts when its user domain changes
    ${before} =    Pod start time
    Execute Command    redis-cli PUBLISH cluster/event/user-domain-changed '{"domains":["other.${user_domain}"]}'
    Sleep    10s
    ${now} =    Pod start time
    Should Be Equal    ${now}    ${before}
    Execute Command    redis-cli PUBLISH cluster/event/user-domain-changed '{"domains":["${user_domain}"]}'
    Wait Until Keyword Succeeds    30 times    5 seconds    Pod restarted since    ${before}
    Wait Until Keyword Succeeds    30 times    5 seconds    Web interface answers

Check if sympa follows the cluster smarthost
    ${saved} =    Run task    cluster/get-smarthost    {}
    ${saved} =    Evaluate    {k: $saved[k] for k in ('host', 'port', 'username', 'password', 'enabled', 'encrypt_smtp', 'tls_verify')}
    # set-smarthost rejects an empty host, even when the smarthost is disabled
    IF    not $saved['host']
        Set To Dictionary    ${saved}    host=localhost
    END
    Set Suite Variable    ${saved_smarthost}    ${saved}
    ${before} =    Pod start time
    # Relay through the mail module of this node, so list mail stays local
    ${local} =    Create Dictionary    host=127.0.0.1    port=${25}    username=${EMPTY}    password=${EMPTY}
    ...    enabled=${TRUE}    encrypt_smtp=none    tls_verify=${FALSE}
    Set the cluster smarthost    ${local}
    Wait Until Keyword Succeeds    30 times    5 seconds    Pod restarted since    ${before}
    Relay host is    [10.0.2.2]:25
    Wait Until Keyword Succeeds    30 times    5 seconds    SMTP service answers

Check if list mail reaches the subscribers
    Subscribe by mail    ${test_mail}
    Wait Until Keyword Succeeds    30 times    5 seconds    List has subscribers    3
    ${subject} =    Evaluate    'Robot post ' + uuid.uuid4().hex    modules=uuid
    ${out}  ${err}  ${rc} =    Execute Command
    ...    /tmp/sympa-send-mail.sh ${list_name}@${list_domain} ${test_mail} "${subject}" "Hello subscribers"
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0    ${err}
    Wait Until Keyword Succeeds    30 times    5 seconds    Mailbox has a message    ${subject}

Check if sympa can be reconfigured
    ${old_host} =    Set Variable    ${sympa_host}
    Set Global Variable    ${sympa_host}    sympa2.domain.test
    Configure sympa    listmasters=["admin@${list_domain}","boss@${list_domain}"]    lang=fr
    ${route} =    Run task    module/traefik1/get-route    {"instance":"${module_id}"}
    Should Be Equal    ${route}[host]    ${sympa_host}
    Wait Until Keyword Succeeds    30 times    5 seconds    Web interface answers
    ${code} =    Execute Command    curl -sk -o /dev/null -w "\%{http_code}" -H "Host: ${old_host}" https://127.0.0.1/sympa
    Should Be Equal    ${code}    404
    ${conf} =    Execute Command    runagent -m ${module_id} podman exec sympa-app cat /etc/sympa/sympa.conf
    Should Contain    ${conf}    listmaster admin@${list_domain},boss@${list_domain}
    Should Contain    ${conf}    lang fr
    Should Contain    ${conf}    wwsympa_url https://${sympa_host}/sympa

Check if the list can be destroyed
    Run task    module/${module_id}/destroy-list    {"name":"${list_name}"}
    ${response} =    Run task    module/${module_id}/list-lists    {}
    ${names} =    Evaluate    [l['name'] for l in $response['lists']]
    Should Not Contain    ${names}    ${list_name}
