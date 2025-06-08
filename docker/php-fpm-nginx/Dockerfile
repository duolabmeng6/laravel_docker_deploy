
FROM registry.cn-hangzhou.aliyuncs.com/llcache/serversideup-php:8.4-fpm-nginx AS base

# FROM base AS development
# USER root
# ARG USER_ID
# ARG GROUP_ID
# RUN echo "USER_ID is: $USER_ID"
# RUN echo "GROUP_ID is: $GROUP_ID"
# RUN docker-php-serversideup-set-id www-data $USER_ID:$GROUP_ID
# USER www-data

FROM base AS production
COPY --chown=www-data:www-data ${BASE_IMAGE_TAG_PREFIX} ${APP_CODE_PATH_CONTAINER}

