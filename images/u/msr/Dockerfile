ARG __msr_image=ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.11

FROM ${__msr_image}

ARG __uid=1001
ARG __img_user_name=sagadmin

ARG __products_home=/opt/softwareag

USER root

RUN usermod -u ${__uid} ${__img_user_name}

USER ${__img_user_name}
