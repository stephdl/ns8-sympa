*** Settings ***
Library    SSHLibrary

*** Variables ***
${CLUSTER_USER}        admin
${CLUSTER_PASSWORD}    Nethesis,1234

*** Test Cases ***
Take screenshots of the module pages
    [Documentation]    Capture what cluster-admin shows for Sympa. Tagged ui: the
    ...                shared runner skips it unless RUN_UI_TESTS is true, since
    ...                it needs a browser.
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True    viewport={'width': 1280, 'height': 900}
    Login to cluster-admin
    Screenshot page    ${EMPTY}          Status      1
    Screenshot page    ?page=lists       Lists       2
    Screenshot page    ?page=settings    Settings    3
    Screenshot page    ?page=about       About       4
    Close Browser

*** Keywords ***
Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Screenshot page
    [Arguments]    ${query}    ${title}    ${index}
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}${query}
    Wait For Elements State    iframe >>> h2 >> text="${title}"    visible    timeout=10s
    # The page fills itself from several tasks: let them land
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/${index}._${title}.png
