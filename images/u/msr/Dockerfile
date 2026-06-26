ARG __msr_image=ibmwebmethods.azurecr.io/webmethods-microservicesruntime:11.1.0.11

FROM ${__msr_image}

ARG __new_user_id=1001
ARG __new_user_id=1001
ARG __img_user_name=sagadmin

ARG __products_home=/opt/softwareag

USER root

RUN usermod -u ${__new_user_id} ${__img_user_name}

USER ${__img_user_name}
