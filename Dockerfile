FROM alpine:3.9

LABEL "com.github.actions.name"="Push a Helm Chart value change, then merge the source branch into a target branch"
LABEL "com.github.actions.description"="A GitHub action for automating Helm values file updates and releases based on Github Release actions"
LABEL "com.github.actions.icon"="arrow-up"
LABEL "com.github.actions.color"="blue"

LABEL "repository"="https://github.com/Nextdoor/helm-release-branch-action"
LABEL "homepage"="https://github.com/Nextdoor/helm-release-branch-action"
LABEL "maintainer"="diranged"

RUN apk --no-cache add openssl git curl openssh-client bash
    
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
